# Builds the app without its tests. The tests use Testcontainers and run in `okteto test`.
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /src

# Download the dependencies in their own layer, so they are only fetched again when pom.xml changes.
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B dependency:go-offline

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B package -DskipTests

FROM eclipse-temurin:21-jre

WORKDIR /app
COPY --from=build /src/target/testcontainers-example-1.0.0.jar app.jar
COPY --from=build /src/target/lib ./lib

EXPOSE 8080
CMD ["java", "-cp", "app.jar:lib/*", "example.HelloWorld"]
