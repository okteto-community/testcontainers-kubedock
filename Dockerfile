# Builds the app and, by default, runs its tests, which use Testcontainers and need a Docker API.
# Okteto builds don't have one, so okteto.yml sets SKIP_TESTS=true and runs the tests in
# `okteto test` instead.
FROM maven:3.9-eclipse-temurin-21 AS build

ARG SKIP_TESTS=false

WORKDIR /src

# Download the dependencies in their own layer, so they are only fetched again when pom.xml changes.
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B package -DskipTests=${SKIP_TESTS}

FROM eclipse-temurin:21-jre

WORKDIR /app
COPY --from=build /src/target/testcontainers-example-1.0.0.jar app.jar
COPY --from=build /src/target/lib ./lib

EXPOSE 8080
CMD ["java", "-cp", "app.jar:lib/*", "example.HelloWorld"]
