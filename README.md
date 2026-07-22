# <img src="https://cdn.simpleicons.org/kubernetes" height="28" alt="Kubernetes" align="center"/> HA multi-zone Go microservices on Kubernetes <img src="https://cdn.simpleicons.org/go" height="28" alt="Go" align="center"/>

Three Go microservices (API Gateway, Books, Movies) deployed in strict High Availability on a local Kind cluster of 9 worker nodes spread over 3 simulated availability zones.

## Collaborators

| Name | Contact |
|---|---|
| Melvin PETIT | melvin.petit31@gmail.com |
| Leith Zniber | leith311.z@hotmail.fr |

## Project context

We must deploy an application in High Availability (HA) mode on a local Kubernetes cluster. The architecture relies on a Kind cluster of 9 worker nodes (3 per zone), spread over three distinct availability zones (AZ): `francecentral-1`, `-2` and `-3`. Node labels are used to simulate those zones.

The application, made of 3 microservices (API Gateway, Books, Movies), must be deployed with Helm or Kustomize in strict HA mode: 3 replicas per service, mandatorily spread over different zones (Required anti-affinity or strict topologySpreadConstraints). An optional constraint across apps is also expected, to favour scheduling pods on "empty" nodes.

### Resilience constraints

- **Accessibility**: the API Gateway must be reachable from the host machine.
- **Health**: StartupProbe, ReadinessProbe and LivenessProbe must be in place, so traffic only reaches healthy and ready pods.
- **Update**: a new version must be rolled out without service interruption (Rolling Update), observable through `kubectl rollout` and verified by a continuous testing tool.

### Chaos engineering (failure simulation)

- **Node failure**: crash of a single worker (`kubectl drain`).
- **Zone failure**: drain of a whole zone (`kubectl drain` x3).
- **Measurement**: in both cases, Siege (or an equivalent) must prove the error rate stays low (for example < 1-2%), thanks to pod spreading and to Kubernetes automatic rescheduling.

### Demo

A live presentation must show:

1. The structure of the deployment (Helm/Kustomize).
2. The update strategy (Rolling Update) and its real-time visualisation (`watch kubectl get pods`).
3. The probes configuration and the zone spreading logic.

Three load tests (LT) are required:

- **Scenario 1**: normal LT (100% success expected).
- **Scenario 2**: LT running + a node is cut.
- **Scenario 3**: LT running + a whole zone is cut.

**Analysis**: explain the theoretical impact of such failures (a single node that goes down, one node per zone going down, a whole zone going down) and conclude on the role of the orchestrator in handling them.

> Advice from the brief: the research and learning process around these concepts, as well as the quality of the demo, are the most valued parts of the final delivery.

### Bonus

- A Traffic Distribution Policy on the services (weighted routing or local affinity) to optimise traffic spreading.
- A PodDisruptionBudget.
- Anything else that looks relevant to satisfy the need.

## Architecture

The three applications are built from a **single Docker image** (three binaries inside), each selected at runtime by the container `command`.

```
   OUTSIDE (http://localhost:8080/data)
        |
        v   LoadBalancer (cloud-provider-kind)
   ┌─────────┐   internal    ┌──────────┐
   │   api   │ ───────────►  │  books   │  (ClusterIP, internal only)
   │ Gateway │ ───────────►  │  movies  │  (ClusterIP, internal only)
   └─────────┘               └──────────┘
   exposed outside          not reachable from outside
```

- **api**: API Gateway, exposed outside through a `LoadBalancer` service. Aggregates books + movies.
- **books**: books service, `ClusterIP` (internal only).
- **movies**: movies service, `ClusterIP` (internal only).

The API reaches the two services by their **Service DNS name**, injected as environment variables:

- `BOOKS_API_HOST=books`
- `MOVIES_API_HOST=movies`

The port is 80, the default HTTP port, so no port suffix is needed: the Go code calls `http://books/books` and `http://movies/movies`.

### Endpoints

| App | Endpoint | Response |
|---|---|---|
| api | `GET /data` | aggregated JSON (books + movies) |
| books | `GET /books` | `{"app":"Books API","data":[...]}` |
| movies | `GET /movies` | `{"app":"Movies API","data":[...]}` |

The API serves on `/data`, **not** on `/`. `http://localhost:8080/` returns 404, `http://localhost:8080/data` returns the aggregated payload.

## Cluster topology

`kind-config.yaml` creates the cluster `francecentral`:

- 3 control-plane nodes, one per zone.
- 9 worker nodes, 3 per zone.
- Every node carries a `zone` label with the value `francecentral-1`, `-2` or `-3`. That label is the topology key used by the scheduling rules, so it plays the role a real cloud provider would fill with `topology.kubernetes.io/zone`.

Check the mapping at any time:

```bash
make status-cluster
```

## HA strategy

Each of the three Deployments carries the same scheduling block.

**Strict spreading across zones** (mandatory constraint):

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: api
        topologyKey: zone
```

`required` means the scheduler refuses to place two pods of the same app in the same zone. With 3 replicas and 3 zones, the only valid placement is one replica per zone. A pod that cannot satisfy the rule stays `Pending` instead of being scheduled in a wrong place, which is exactly what "strict HA" means: we prefer a missing pod to a badly placed one.

**Spreading over empty nodes** (optional constraint):

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchExpressions:
        - key: app
          operator: Exists
```

Here the topology key is the node, not the zone, and the selector targets every pod carrying an `app` label, so all three microservices are counted together. The goal is to avoid stacking api + books + movies on the same worker while other workers stay empty. `ScheduleAnyway` makes it a soft preference: if it cannot be respected, the pod is still scheduled. Combined with the zone anti-affinity above, we get "one replica per zone, and inside a zone, on the emptiest node".

**Probes** (identical on the three services, TCP on port 8080):

| Probe | Role | Settings |
|---|---|---|
| startupProbe | gives the app time to boot before the other probes apply | `initialDelay 10s`, `period 5s`, `failureThreshold 30` |
| readinessProbe | removes the pod from the Service endpoints while it cannot serve | `initialDelay 5s`, `period 10s`, `failureThreshold 3` |
| livenessProbe | restarts the container when it is stuck | `initialDelay 5s`, `period 10s`, `failureThreshold 3` |

The readiness probe is the one that protects the load test: during a rolling update or a drain, a pod that is not ready receives no traffic, so no request lands on a container that is still starting.

**Rolling update**:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 0
    maxUnavailable: 1
```

`maxSurge: 0` is not the usual default, and it is a direct consequence of the strict anti-affinity. With `maxSurge: 1`, Kubernetes would try to create a fourth pod before deleting an old one, but every zone already hosts a pod of that app, so the new pod could never be scheduled and the rollout would deadlock on `Pending`. Removing one pod first frees a zone, the replacement takes its place, and the rollout progresses one pod at a time while 2 of 3 replicas keep serving.

## Requirements

- Docker
- kind
- kubectl
- Go (to build cloud-provider-kind)
- cloud-provider-kind (LoadBalancer support on kind)
- siege (load testing)

```bash
go install sigs.k8s.io/cloud-provider-kind@latest
```

## Project layout

```
kind-config.yaml            # cluster: 3 control-planes + 9 workers, zone labels
Makefile                    # cluster, deployments, services, status targets
Dockerfile                  # single image, 3 binaries
cmd/{api,books,movies}      # Go sources
k8s/
  api/     api-deployment.yaml     api-service.yaml     (LoadBalancer)
  books/   books-deployment.yaml   books-service.yaml   (ClusterIP)
  movies/  movies-deployment.yaml  movies-service.yaml  (ClusterIP)
docs/CONSIGNES.md           # brief of the previous iteration (single-zone HA)
```

## Deploy

**1. Build the image** (the Makefile loads it into the cluster right after creation, so build first)

```bash
docker build -t microservices:1.0 .
```

**2. Create the cluster and load the image**

```bash
make create-cluster
```

**3. Deploy the manifests**

```bash
make deployments
make services
```

Or in one shot:

```bash
kubectl apply -R -f k8s/
```

**4. Start cloud-provider-kind** (leave it running in its own terminal)

```bash
sudo cloud-provider-kind
```

The API service then gets an `EXTERNAL-IP`:

```bash
kubectl get svc api
```

**5. Check the placement**

```bash
make status-cluster
kubectl get pods -o wide
```

Expected: 9 pods, 3 per app, and for each app one pod per zone.

## Access

```bash
curl http://localhost:8080/data
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

### WSL2 note (LoadBalancer)

On WSL2, cloud-provider-kind may assign the LoadBalancer IP to the host loopback (`lo`). When that happens, the host treats the IP as local and `localhost:8080` hangs. Remove the address from loopback:

```bash
sudo ip addr del <EXTERNAL-IP>/32 dev lo
```

If cloud-provider-kind re-adds it during a later sync and access breaks again, run the command again.

## Rolling update demo

Terminal 1, watch the pods:

```bash
watch -n1 kubectl get pods -o wide
```

Terminal 2, continuous traffic:

```bash
siege -c 10 -t 2M http://localhost:8080/data
```

Terminal 3, roll out a new version:

```bash
docker build -t microservices:2.0 .
kind load docker-image microservices:2.0 -n francecentral
kubectl set image deployment/api api=microservices:2.0
kubectl rollout status deployment/api
```

Rollback if needed:

```bash
kubectl rollout undo deployment/api
```

## Chaos tests

The three scenarios run with siege on `http://localhost:8080/data` while the failure is injected.

**Scenario 1: baseline**

```bash
siege -c 10 -t 1M http://localhost:8080/data
```

Expected: 100% availability, no failed transaction.

**Scenario 2: single node failure**

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
```

The pods hosted on that node are evicted. Because each app already has one replica per zone, the api Service keeps 2 healthy endpoints out of 3 while the evicted pod is rescheduled. With strict anti-affinity, the evicted pod can only come back on another node **of the same zone**, which exists since there are 3 workers per zone.

**Scenario 3: whole zone failure**

```bash
kubectl drain <node-zone-3-a> <node-zone-3-b> <node-zone-3-c> --ignore-daemonsets --delete-emptydir-data --force
```

The zone loses its 3 workers, so each app loses exactly 1 of its 3 replicas. The evicted pods stay `Pending`: no other zone can host them without breaking the `required` anti-affinity. The service keeps running on the 2 remaining zones, degraded but available.

Bring the nodes back:

```bash
kubectl uncordon <node>
```

Measurement to report for each scenario: siege's `Availability`, `Failed transactions` and `Longest transaction`.

## Analysis

**Single node, no replication.** The application dies with its node. Availability drops to 0 until a human intervenes. That is the baseline every HA mechanism is compared to.

**Three replicas on one node.** Replication alone protects against a process crash, not against a machine loss. Losing the node loses the three replicas at once, so the blast radius is unchanged. Replication is only worth its cost once it is spread.

**One node per zone goes down (3 nodes, one in each zone).** Each app loses one replica in each affected zone, but the surviving workers of the same zone can take them back. Kubernetes reschedules within seconds, readiness probes keep traffic away from the pods that are still starting, and the error rate stays in the low single digits, coming only from the connections in flight at eviction time.

**A whole zone goes down.** One third of the capacity is gone and stays gone: the strict anti-affinity forbids rebuilding the missing replica anywhere else. This is a deliberate trade-off. A `preferred` rule would restore 3 running replicas immediately, but would concentrate 2 of them in the same zone, so the next zone failure would take down two thirds of the app instead of one third. `required` chooses guaranteed spreading over guaranteed replica count, which is the right call when the failure domain is what we are protecting against.

**Role of the orchestrator.** Kubernetes handles the whole loop without human input: it detects the unhealthy pods through the probes, removes them from the Service endpoints so no request is routed to them, evicts and reschedules the workloads according to the placement constraints, and converges back to the declared desired state as soon as capacity comes back. The orchestrator does not prevent failures; it makes them non-events by turning "the machine is down" into "the desired state is temporarily unmet".

## Cleanup

```bash
make delete-cluster
```

## Result

![result.png](img.png)
