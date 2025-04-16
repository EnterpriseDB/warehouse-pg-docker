
#  WarehousePG Single-Node Setup with Docker

This Docker VM sets up WarehousePG on Rocky Linux 8. To install a different version, simply modify the Dockerfile accordingly.

## Docker Build and Run Instructions

## 1. Clone the Repository
Clone this repository and navigate to the `single-node` directory:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd single-node
```

### 2. Export your EDB Repos 2.0 Token

If you are using `zshrc`

```bash
echo 'export EDB_REPO_TOKEN=<YOUR TOKEN>' >> ~/.zshrc
source ~/.zshrc
```

If you are using `bash`

```bash
echo 'export EDB_REPO_TOKEN=<YOUR TOKEN>' >> ~/.bashrc
source ~/.bashrc
```

### 3. Enable Docker BuildKit

First, enable Docker BuildKit to improve the build performance and capabilities:

```bash
export DOCKER_BUILDKIT=1
```

### 4. Build the Docker Image

Use the following command to build the Docker image, specifying the secret `EDB_REPO_TOKEN`:

```bash
docker build --secret id=EDB_REPO_TOKEN --platform linux/amd64 --no-cache -t warehousepg-el8 .
```

### 5. Run the Docker Container

After building the image, you can run the container with the following command:

```bash
docker run --hostname mdw --name mdw -it warehousepg-el8
```

### 6. Connect Back to the Container

To connect back to the running Docker container, use the following command:

```bash
docker exec -it mdw /bin/bash
```

If it doesn't work, start the container and then connect again:

```bash
docker start mdw
docker exec -it mdw /bin/bash
```

### 7. Starting and Stopping the Container

- **To start the container**:

  ```bash
  docker start mdw
  ```

- **To stop the container**:

  ```bash
  docker stop mdw
  ```