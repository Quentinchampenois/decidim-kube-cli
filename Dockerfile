FROM bitnami/kubectl:1.20.9 as kubectl

# Use an official Ruby runtime as a parent image
FROM ruby:3.2-alpine

# Set environment variables for the script
ENV KUBECONFIG=/.kube/config \
    AIRBYTE_ENDPOINT=http://localhost:8006/ \
    AIRBYTE_BASIC_AUTH=true \
    AIRBYTE_USERNAME=airbyte \
    AIRBYTE_PASSWORD=password \
    DB_PORT=5432 \
    DB_NAME=your_database_name \
    WORKSPACE_UUID=your_workspace_uuid_here

# Install any additional system packages required for Open3 and other Ruby dependencies
RUN apk --no-cache add build-base jq curl

# Set the working directory in the container
WORKDIR /app

# Copy only the Gemfile and Gemfile.lock to install dependencies
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
RUN bundle install

# Copy the current directory contents into the container at /usr/src/app
COPY . /app
COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/

# Run the script when the container launches
CMD ["bundler", "exec", "main.rb"]
