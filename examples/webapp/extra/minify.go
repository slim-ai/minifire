package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"github.com/nathants/cli-aws/lib"
	yaml "gopkg.in/yaml.v3"
)

func cleanup() {
	_ = exec.Command("docker", "compose", "--profile=all", "kill").Run()
	_ = exec.Command("docker", "compose", "--profile=all", "rm", "-f").Run()
}

func minify() error {
	cleanup()
	defer cleanup()

	// start trace
	_ = exec.Command("killall", "docker-trace", "-s", "INT").Run()
	cmdTrace := exec.Command("docker-trace", "files")
	cmdTraceStdout, err := os.Create("/tmp/files.txt")
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	cmdTrace.Stdout = cmdTraceStdout
	stderr, err := cmdTrace.StderrPipe()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	err = cmdTrace.Start()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// wait for trace to be ready
	scanner := bufio.NewScanner(stderr)
	for scanner.Scan() {
		line := string(scanner.Bytes())
		line = strings.TrimRight(line, "\n")
		if line == "ready" {
			fmt.Println("trace started")
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	err = scanner.Err()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// services up
	err = exec.Command("docker", "compose", "--profile=run", "up", "-d").Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// test up
	err = exec.Command("docker", "compose", "--profile=test", "up", "-d").Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// tail the logs
	cmdLogs := exec.Command("docker", "compose", "logs", "-f")
	cmdLogs.Stderr = os.Stderr
	cmdLogs.Stdout = os.Stdout
	err = cmdLogs.Start()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// get test container id
	var psData []map[string]interface{}
	var cmdPsStdout bytes.Buffer
	cmdPs := exec.Command("docker", "compose", "ps", "--format", "json")
	cmdPs.Stdout = &cmdPsStdout
	err = cmdPs.Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	err = json.Unmarshal(cmdPsStdout.Bytes(), &psData)
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	testId := ""
	for _, val := range psData {
		if val["Service"] == "test" {
			testId = val["ID"].(string)
			break
		}
	}
	if testId == "" {
		panic("no test container id")
	}

	// wait for test container to exit
	err = exec.Command("docker", "wait", testId).Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// get test container exit code
	psData = nil
	cmdPsStdout = bytes.Buffer{}
	cmdPs = exec.Command("docker", "compose", "ps", "--format", "json")
	cmdPs.Stdout = &cmdPsStdout
	err = cmdPs.Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	err = json.Unmarshal(cmdPsStdout.Bytes(), &psData)
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	exitCode := -1
	for _, val := range psData {
		if val["Service"] == "test" {
			exitCode = int(val["ExitCode"].(float64))
			break
		}
	}
	if exitCode != 0 {
		panic("tests failed")
	}

	// stop trace
	fmt.Println("stop trace")
	_ = exec.Command("docker", "compose", "--profile=all", "kill").Run()
	_ = cmdTrace.Process.Signal(syscall.SIGINT)
	_ = cmdTrace.Wait()
	err = cmdTraceStdout.Close()
	if err != nil {
		lib.Logger.Println("error:", err)
	    return err
	}
	fmt.Println("trace stopped")

	// read docker-compose.yml
	data, err := ioutil.ReadFile("docker-compose.yml")
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	var composeData map[string]interface{}
	err = yaml.Unmarshal(data, &composeData)
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// read compose ps
	psData = nil
	cmdPsStdout.Reset()
	cmdPs = exec.Command("docker", "compose", "ps", "--format", "json")
	cmdPs.Stdout = &cmdPsStdout
	err = cmdPs.Run()
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}
	err = json.Unmarshal(cmdPsStdout.Bytes(), &psData)
	if err != nil {
		lib.Logger.Println("error:", err)
		return err
	}

	// minify each service
	for _, val := range psData {

		// get names and ids
		id := val["ID"].(string)
		serviceName := val["Service"].(string)

		// do not minify test container by default
		if os.Getenv("MINIFY_TEST") == "" && serviceName == "test" {
			continue
		}

		services := composeData["services"].(map[string]interface{})
		service := services[serviceName].(map[string]interface{})
		containerIn := service["image"].(string)
		cmdResolveEnvVars := exec.Command("bash", "-c", "echo -n "+containerIn)
		var cmdResolveEnvVarsStdout bytes.Buffer
		cmdResolveEnvVars.Stdout = &cmdResolveEnvVarsStdout
		err = cmdResolveEnvVars.Run()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}
		containerIn = cmdResolveEnvVarsStdout.String()
		containerOut := containerIn + "-minified"
		fmt.Println("minify", containerIn, "=>", containerOut)

		// start minify
		cmdMinify := exec.Command("docker-trace", "minify", containerIn, containerOut)
		cmdMinify.Stderr = os.Stderr
		cmdMinify.Stdout = os.Stdout
		cmdMinifyStdin, err := cmdMinify.StdinPipe()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}
		err = cmdMinify.Start()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}

		// write files to keep to stdin
		f, err := os.Open("/tmp/files.txt")
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}
		seen := make(map[string]interface{})
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimRight(string(scanner.Bytes()), "\n")
			lineId, lineVal, err := lib.SplitOnce(line, " ")
			if err != nil {
				lib.Logger.Println("error:", err)
			    return err
			}
			if id == lineId {
				_, ok := seen[lineVal]
				if !ok {
					fmt.Println("include:", lineVal)
					seen[lineVal] = nil
				}
				_, err := cmdMinifyStdin.Write([]byte(lineVal+"\n"))
				if err != nil {
					lib.Logger.Println("error:", err)
					return err
				}
			}
		}
		err = scanner.Err()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}
		err = cmdMinifyStdin.Close()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}

		// wait for minify
		err = cmdMinify.Wait()
		if err != nil {
			lib.Logger.Println("error:", err)
			return err
		}
	}

	return nil
}

func main() {
	err := minify()
	if err != nil {
		panic(err)
	}
}
