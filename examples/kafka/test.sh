set -xeou pipefail

pacman -Sy --needed --noconfirm curl jq

for i in {1..120}; do
    curl -f rest-proxy:8082/ && break
    echo wait for rest-proxy $i
    sleep 1
done

KAFKA_CLUSTER_ID=$(curl rest-proxy:8082/v3/clusters/ | jq  -r ".data[0].cluster_id")

curl -f \
     -X POST \
     -H "Content-Type: application/json" \
     -d "{\"topic_name\":\"test1\",\"partitions_count\":6,\"configs\":[]}" \
     "rest-proxy:8082/v3/clusters/${KAFKA_CLUSTER_ID}/topics" \
    | jq .

curl -f \
     -X POST \
     -H "Content-Type: application/vnd.kafka.json.v2+json" \
     -H "Accept: application/vnd.kafka.v2+json" \
     -d '{"records":[{"key":"alice","value":{"count":0}},{"key":"alice","value":{"count":1}},{"key":"alice","value":{"count":2}}]}' \
     "rest-proxy:8082/topics/test1" \
    | jq .

curl -f \
     -X POST \
     -H "Content-Type: application/vnd.kafka.json.v2+json" \
     -d '{"name": "ci1", "format": "json", "auto.offset.reset": "earliest"}' \
     "rest-proxy:8082/consumers/cg1" \
    | jq .

curl -f -X POST \
     -H "Content-Type: application/vnd.kafka.json.v2+json" \
     -d '{"topics":["test1"]}' \
     "rest-proxy:8082/consumers/cg1/instances/ci1/subscription" \
    | jq .

curl -f -X GET \
     -H "Accept: application/vnd.kafka.json.v2+json" \
     "rest-proxy:8082/consumers/cg1/instances/ci1/records" \
    | jq .
