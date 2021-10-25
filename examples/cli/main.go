package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/alexflint/go-arg"
)

type Args struct {
	Url             string `arg:"positional,required" help:"url to fetch"`
	Method          string `arg:"-m,--method" default:"GET" help:"GET | POST"`
	FollowRedirects bool   `arg:"-f,--follow" help:"follow redirects"`
}

func Pformat(i interface{}) string {
	val, err := json.MarshalIndent(i, "", "    ")
	if err != nil {
		panic(err)
	}
	return string(val)
}

func main() {
	var args Args
	arg.MustParse(&args)
	if !strings.Contains(args.Url, "://") {
		args.Url = "https://" + args.Url
	}
	//
	c := http.Client{}
	if !args.FollowRedirects {
		c.CheckRedirect = func(req *http.Request, via []*http.Request) error { return http.ErrUseLastResponse }
	}
	//
	var out *http.Response
	var err error
	switch args.Method {
	case "GET":
		out, err = c.Get(args.Url)
	case "POST":
		panic("TODO implement POST")
	default:
		panic(fmt.Sprint("unknown method:", args.Method))
	}
	//
	if err != nil {
		panic(err)
	}
	defer func() { _ = out.Body.Close() }()
	fmt.Fprintln(os.Stderr, "GET", args.Url, out.StatusCode)
	fmt.Fprintln(os.Stderr, Pformat(out.Request.Header))
	fmt.Fprintln(os.Stderr, Pformat(out.Header))
	_, err = io.Copy(os.Stdout, out.Body)
	if err != nil {
		panic(err)
	}
	code := fmt.Sprint(out.StatusCode)[:1]
	if code != "2" && code != "3" {
		os.Exit(1)
	}
}
