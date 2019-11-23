# apartment listings

Example Locust web scraper to collect the latest 100 Craigslist apartment home listings in New York City. Runs on Amazon Web Services and uses RDS, ElasticCache, and AWS Lambda.

## Cloud

### Setup

1. Setup and configure [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
1. Install [terraform](https://www.terraform.io/downloads.html)
1.  Run `terraform init` in the `infra` directory
1. Install [Postgres CLI 10.x (psql)](https://www.postgresql.org/download/)
    * `psql` is nesecessary to run the `db/schema/setup.sql` on the RDS instance. The `provisioner` block can alternately be commented out and any Postgres client can be used to run the setup script

### Deploy

1. Zip source
    ```sh
    npm run build
    ```
1. Generate postgres password
    ```sh
    echo "postgres_password=\"$(openssl rand -base64 14)\"" > infra/terraform.tfvars
    ```
1. Deploy infrastructure and source
    ```sh
    cd infra && terraform apply
    ```

More information in the [deployment guide](https://locust.dev/docs/deploy)

### Invoke

```sh
aws lambda invoke \
--invocation-type Event \
--function-name apartment-listings \
--region us-east-1  \
--profile default \
out.txt
```

More information in the [operational guide](https://locust.dev/docs/operate)

### Notes

* Security - The infrastructure in this example is not intended for production or long-term use cases as it prioritizes convenience over security

## Local

### Setup

1. Install [locust-cli](https://www.npmjs.com/package/@achannarasappa/locust-cli)
1. Install [Docker Compose](https://docs.docker.com/compose/install/)
1. Install [NodeJS](https://nodejs.org/en/download/package-manager/#nvm)

### Run

1. Start local dependencies
    ```sh
    docker-compose up
    ```
1. Start job via cli
    ```sh
    locust start src/job.js
    ```