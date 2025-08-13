FROM python:3.10-slim

WORKDIR /app

# Install common CLI tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim less procps bash curl iputils-ping net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY generate_data.py ./

#CMD ["python", "generate_data.py"]
CMD ["bash"]
