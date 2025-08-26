# Technical Decisions

## Why These Choices?

Here's why I made certain architectural decisions for this challenge.

## Multi-Region Setup

Chose us-central1 + europe-west1 instead of just using multiple zones in one region.

Single regions represent a single point of failure for regional-level incidents. Regional outages do occur across cloud providers, so multi-region deployment provides genuine high availability protection.

The trade-off is increased complexity - cross-region networking, monitoring across regions, and higher costs. For a high availability demonstration, this approach showcases true resilience.

Alternative was just multiple zones, but that doesn't protect against regional outages.

## Terraform Modules

Structured the infrastructure into separate modules (VPC, GKE, monitoring, etc.) rather than monolithic configuration.

This enables isolated changes to specific components without affecting other parts of the infrastructure. Each module can be developed and maintained independently.

Additional benefits include team ownership of specific modules and reusability across environments.

The trade-off is increased complexity in file management and state coordination. However, for projects beyond basic demos, modular architecture provides better maintainability.

## GKE vs Self-Managed Kubernetes

Chose GKE instead of self-managed Kubernetes.

Managing Kubernetes control planes requires significant operational overhead. Google handles updates, security patches, and control plane scaling automatically.

The trade-off is higher costs compared to raw VMs and vendor lock-in to GCP. However, the reduced operational burden makes it worthwhile for most use cases unless you have specific control plane customization requirements.

## Canary Deployments

Implemented canary deployments (gradual traffic shift to new versions) rather than blue-green deployments.

Canary deployments allow testing with production traffic while limiting impact scope. If issues arise, only a small percentage of users are affected. Blue-green deployments require double infrastructure capacity and involve larger deployment risks.

The trade-off is implementation complexity - requiring traffic splitting logic and health monitoring systems. However, for production environments, gradual rollouts provide better risk management.

## Zero-Trust Network Policies

Default deny-all, explicit allow what's needed.

Traditional approach is "firewall at the perimeter" but that doesn't help if something gets inside your network. Zero-trust means even internal services can't talk to each other unless explicitly allowed.

More configuration overhead, and debugging network issues gets harder. But security-wise it's much better.

## Secrets with Vault

Could have just used Kubernetes secrets, but Vault gives proper secret rotation, access control, and audit trails.

Kubernetes secrets are just base64-encoded (not really encrypted) and don't rotate. Vault is more complex to set up but much better for anything production.

## Prometheus vs Cloud Monitoring

Went with Prometheus for custom metrics instead of just using GCP's monitoring.

Cloud Monitoring is simpler and integrates well with GCP services. But Prometheus gives more flexibility for application metrics and doesn't charge per metric.

Downside is you have to run and scale Prometheus yourself. For cost-sensitive or metric-heavy workloads, it's worth it.

## Auto-scaling Strategy

Using both horizontal pod autoscaling (HPA) and cluster autoscaling.

HPA scales pods based on CPU/memory/custom metrics. Cluster autoscaling adds/removes nodes based on pod resource requests.

This means the system can handle traffic spikes by adding pods, and if there aren't enough nodes, it adds those too. Costs scale with demand instead of being fixed.

## Container Security

Multi-stage Docker builds, non-root user, minimal base image.

Security scanning catches known vulnerabilities. Running as non-root limits damage if container is compromised. Minimal base image reduces attack surface.

All adds some complexity to the build process but standard security practices.

## Cost Considerations

Used auto-scaling to match demand, efficient resource allocation.

Auto-scaling means not paying for idle resources during low traffic periods. Node pools can scale down when not needed.

For a real production system, you'd want to analyze usage patterns and optimize further.

## What I Skipped

Some things I didn't implement due to time/scope:

- Complete backup/restore procedures  
- Advanced security scanning in CI/CD
- Performance testing automation
- Complete disaster recovery automation
- Service mesh observability (distributed tracing)

These would be next steps for a production system.
