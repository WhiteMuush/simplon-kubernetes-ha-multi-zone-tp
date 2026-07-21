# simplon-kubernetes-microservices-tp

Deploying a Go microservices application on Kubernetes (kind).

## Architecture

Three applications, a single Docker image:

- **api**: API Gateway, exposed outside the cluster. Aggregates data from both services.
- **books**: books service, internal only.
- **movies**: movies service, internal only.

The API talks to the services through the cluster's internal network. It needs two environment variables:

- `BOOKS_API_HOST`
- `MOVIES_API_HOST`

## Requirements

- Docker
- kind
- kubectl

## Getting started

```bash
# build the image
docker build -t microservices:latest .

# load the image into kind
kind load docker-image microservices:latest

# deploy
kubectl apply -f k8s/
```

## Test

```bash
curl http://localhost:8080
```

Expected response:

```json
{
  "app": "API Gateway",
  "data": {
    "books": ["Book 1", "Book 2", "Book 3"],
    "movies": ["Movie 1", "Movie 2", "Movie 3"]
  }
}
```

## Brief

See [docs/CONSIGNES.md](docs/CONSIGNES.md).
