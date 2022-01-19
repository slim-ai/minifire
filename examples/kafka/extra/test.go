package main

import (
	"context"
	"fmt"
	"time"

	kafka "github.com/segmentio/kafka-go"
)

func test() error {
	writer := &kafka.Writer{
		Addr:     kafka.TCP("localhost"),
		Topic:    "topic",
		Balancer: &kafka.LeastBytes{},
	}
	err := writer.WriteMessages(context.Background(), kafka.Message{
		Key:   []byte("hi"),
		Value: []byte("there"),
	})
	if err != nil {
		return err
	}
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers: []string{"localhost"},
		Topic:   "topic",
	})
	msg, err := reader.ReadMessage(context.Background())
	if err != nil {
		return err
	}
	if string(msg.Key) != "hi" || string(msg.Value) != "there" {
		return fmt.Errorf("fail: %s %s", string(msg.Key), string(msg.Value))
	}
	return nil
}

func main() {
	start := time.Now()
	for {
		if time.Since(start) > 1*time.Minute {
			panic("timeout")
		}
		err := test()
		if err == nil {
			return
		}
		fmt.Println("retrying because:", err)
		time.Sleep(1*time.Second)
	}
}
