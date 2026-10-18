# Lesson 01: prepare the host and workspace

Goal: verify the Linux workstation and Docker access before creating any Kubernetes nodes. Run the commands yourself from your WSL distribution's Bash terminal.

## Completion and setup observations

The owner confirmed that Step 01 is complete. The table records observations collected during setup; it is not a list of requirements for other machines.

| Item | Observed value |
| --- | --- |
| Linux distribution | Ubuntu 26.04.1 LTS on WSL 2, x86_64 |
| WSL-visible CPU | 32 logical processing units |
| WSL-visible memory | About 15 GiB total, about 14 GiB available at the initial check |
| Git | 2.53.0, Ubuntu package at `/usr/bin/git` |
| Docker | Linux client/server 29.7.2, Docker Desktop 4.86.0 |
| kind | 0.33.0, installed at `/usr/local/bin/kind` |
| kubectl | 1.36.1, with Kustomize 5.8.1 |
| Shared CLI tools | Docker and kubectl link to Docker Desktop's Linux CLI files |

The owner confirmed the remaining host checks, including the test container. Their output is not reproduced here. The initial `df` result described Ubuntu's virtual disk; it must not be presented as a measurement of physical free space on Windows.

Ubuntu is now the owner's personal Linux workstation. The instructions below remain as a setup reference. Continue with [Lesson 02: create the cluster](02-create-the-cluster.md).

## Know which terminal you are using

| Terminal | Role in the lab | How you reach it |
| --- | --- | --- |
| WSL distribution | Operator workstation: Git, Docker CLI, kind, and `kubectl` | Open your installed Linux distribution's terminal |
| kind node container | Occasional inspection of a simulated machine | Later: `docker exec -it bank-lab-worker bash` |
| Application container | Inspect a running API or database process | Later: `kubectl exec -it -n bank-lab <pod-name> -- sh` |

The last two commands are examples for later steps; no such nodes or Pods are expected yet. Use the real container name and a shell present in its image. `exec` starts a process inside a running container. It does not connect through SSH, and the lab does not need SSH servers inside its containers.

Keep normal administration in WSL and durable configuration in repository files. A container shell is useful for inspection; a change made only inside a container may disappear when it is replaced.

## 0. Establish the WSL operator distribution

The initial inventory on this machine listed only `docker-desktop`, running in WSL 2 mode. That is Docker Desktop's internal backend distribution. The attempt to start Bash in the default WSL target failed because Bash was not available.

Before running the Linux commands below:

1. Install Ubuntu from the Microsoft Store, or choose another supported WSL development distribution. The WSL platform is already present; the missing part is the user-facing Linux distribution.
2. Launch that distribution and complete its Linux username/password setup.
3. In Docker Desktop, enable that distribution under **Settings > Resources > WSL Integration**. The distribution must use WSL 2.

These are initial Windows-side application settings. All routine terminal commands in the lab will then run in the Linux distribution. Leave Docker Desktop's internal distribution alone; open the Ubuntu or other chosen distribution's terminal instead.

## 1. Locate the existing checkout

```bash
cd /mnt/c/Me/Dev/learning/k8s_commands
pwd
git status --short
```

This is the existing checkout accessed through its Linux mount path. Do not run `git init` again or make another clone just to start using WSL. Git configuration and authentication in your Linux distribution may need separate setup when you next commit or push.

The files are currently on the mounted Windows drive. A checkout under your Linux home directory can improve Linux filesystem performance, but moving it is a separate choice; the initial checks work in the current location.

The repository's `.gitattributes` keeps text files on Linux LF line endings, including when Git is used from Windows. This avoids introducing Windows line endings into future Bash scripts.

## 2. Inspect Linux and the resources visible to WSL

```bash
cat /etc/os-release
uname -r
nproc
free -h
df -h .
```

- `os-release` identifies the distribution, which determines package installation instructions.
- `uname -r` reports the kernel version. WSL 2 normally identifies its kernel here.
- `nproc` reports available processing units for the current Linux environment.
- `free -h` reports Linux memory totals and current availability.
- `df -h .` reports capacity on the filesystem holding this checkout.

These are the resources visible to WSL, not automatically the complete Windows host budget or Docker engine allocation. Docker stores images and volumes separately from the checkout; inspect its storage and available disk space before pulling large images.

## 3. Check tool locations and versions

```bash
command -v git docker kind kubectl
git --version
docker version
kind version
kubectl version --client
```

Use Linux commands and binaries. `command -v` helps identify which program is being executed; investigate an alias or wrapper that unexpectedly calls a Windows executable. Docker Desktop may expose its Linux CLI through its WSL integration.

A missing command is a useful result. Record it rather than installing an arbitrary version. If a tool is absent, select its installation method after checking the distribution and architecture. `kubectl version --client` does not require a cluster.

`docker version` should report both a client and a reachable server. A client-only result or connection error means Docker access still needs attention. With the planned Docker Desktop setup, enable integration for your distribution in **Settings > Resources > WSL Integration**, and use Linux container mode. Avoid installing a second Docker daemon as an automatic workaround.

## 4. Inspect the Docker engine's view

```bash
docker context show
docker info --format 'OS={{.OSType}} CPUs={{.NCPU}} MemoryBytes={{.MemTotal}}'
docker system df
```

Check that the intended Docker engine is selected and that `OS=linux`. Compare its reported resources with WSL's view. `docker system df` shows Docker disk usage, not the free capacity of its backing disk. These commands do not delete images or change contexts.

Do not choose application requests and limits yet. First establish what capacity the host and Docker backend can actually provide for the control plane, three workers, database, API, and traffic generator. kind node containers share that capacity.

## 5. Verify one ordinary Linux container

After the Docker checks succeed:

```bash
docker run --rm hello-world
```

This pulls the test image if needed, runs a short container, and removes the stopped container afterward. The downloaded image may remain cached. A successful greeting confirms basic image-pull and container execution; it does not create or validate a Kubernetes cluster.

## 6. Check the versioned local configuration

The root `.env` contains the initial local database name, user, and password. These are deliberately public fixture values for disposable local services, and the repository is meant to retain them in Git. No application or Kubernetes resource loads them yet.

```bash
git status --short
git check-ignore .env
```

For `.env`, `git check-ignore` should print nothing and exit with status 1, meaning no ignore rule excludes it. That exit status is expected. If `.env` is already tracked, check its ignore-rule behavior independently with `git check-ignore --no-index .env`; the same no-match result is expected. Adding the file to a commit remains your normal Git workflow.

Generated kubeconfigs remain ignored: kind creates per-cluster access files containing instance-specific endpoints and access data. This generated-file exception does not apply to the committed local database password or to local Kubernetes Secret definitions.

## Finish the step

Record the distribution, architecture (`uname -m`), WSL-visible resources, Docker engine resources, tool versions, and test-container result. Note missing tools and failed checks so their fixes can be specific to your environment.

Step 01 is complete when the required Linux tools are available, the intended Linux Docker engine is reachable, the test container succeeds, and the resource observations and installation choices are recorded. Create the kind cluster in step 02.

## References

- [Docker Desktop WSL integration](https://docs.docker.com/desktop/features/wsl/)
- [Install a WSL Linux distribution from the Microsoft Store](https://learn.microsoft.com/en-us/windows/wsl/install-manual#step-6---install-your-linux-distribution-of-choice)
- [Docker exec](https://docs.docker.com/reference/cli/docker/container/exec/)
- [Get a shell in a Kubernetes container](https://kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/)
- [Microsoft guidance on WSL filesystems](https://learn.microsoft.com/en-us/windows/wsl/filesystems)
