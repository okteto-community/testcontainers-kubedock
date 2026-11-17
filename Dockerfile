# Builds the app without running the tests. The tests, which use Testcontainers, run in
# `okteto test` and `okteto deploy` instead (see okteto.yml).
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /src
COPY pom.xml .
COPY src ./src

RUN mvn -B package -DskipTests

FROM eclipse-temurin:21-jre

WORKDIR /app
COPY --from=build /src/target/testcontainers-example-1.0.0.jar app.jar
COPY --from=build /src/target/lib ./lib

CMD ["java", "-cp", "app.jar:lib/*", "example.HelloWorld"]
