package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var True = true

func client() *mongo.Client {
	client, err := mongo.Connect(context.Background(), options.Client().ApplyURI("mongodb://localhost:27017"))
	if err != nil {
		panic(err)
	}
	return client
}

func handlerWipe(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	err := client().Database("main").Collection("values").Drop(context.Background())
	if err != nil {
	    panic(err)
	}
}

func handlerValue(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	var result bson.D
	err := client().Database("main").Collection("values").FindOneAndUpdate(
		context.Background(),
		bson.D{{"name", "value"}},
		bson.D{{"$inc", bson.D{{"value", 2}}}},
		&options.FindOneAndUpdateOptions{Upsert: &True},
	).Decode(&result)
	var data []byte
	if err != nil {
		if !errors.Is(err, mongo.ErrNoDocuments) {
			panic(err)
		}
		data, err = json.Marshal(0)
		if err != nil {
			panic(err)
		}
	} else {
		data, err = json.Marshal(result.Map()["value"])
		if err != nil {
			panic(err)
		}
	}
	fmt.Println("200 /value", string(data))
	_, err = w.Write(data)
	if err != nil {
		panic(err)
	}
}

func main() {
	http.HandleFunc("/value", handlerValue)
	http.HandleFunc("/wipe", handlerWipe)
	fmt.Println("start server")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		panic(err)
	}
}
