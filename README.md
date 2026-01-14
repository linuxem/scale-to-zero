# Scale Crashing Deployments to Zero

This project contains a script that identifies Kubernetes deployments with pods in a `CrashLoopBackOff` state and scales them to zero replicas. This helps in stabilizing a namespace by stopping failing workloads.

## Usage

1.  Ensure you have `kubectl` installed and configured to point to your desired cluster.
2.  Run the script with the target namespace as an argument:

```bash
./scale_to_zero.sh <namespace>
```

## Behavior

The script will:
1.  List all pods in the specified namespace.
2.  Filter for pods with the status `CrashLoopBackOff`.
3.  Trace the ownership of these pods (Pod -> ReplicaSet -> Deployment).
4.  Scale only the affected Deployments to 0.

## Example

To scale crashing deployments in the `dev-environment` namespace:

```bash
./scale_to_zero.sh dev-environment
```
