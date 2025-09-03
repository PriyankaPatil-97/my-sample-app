FROM eclipse-temurin:17-jdk-alpine
WORKDIR /app
# Copy the packaged jar
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
