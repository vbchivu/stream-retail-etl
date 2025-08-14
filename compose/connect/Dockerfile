FROM confluentinc/cp-kafka-connect:7.6.0

# Install the JDBC sink plugin once at build time (stable & fast at runtime)
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.5

# Default entrypoint runs the Connect worker; no extra commands needed
