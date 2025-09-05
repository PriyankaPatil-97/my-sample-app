FROM openjdk:17-jdk-slim
ARG APP_PORT=9090
ENV APP_PORT=${APP_PORT}
EXPOSE ${APP_PORT}
COPY target/*.jar app.jar
ENTRYPOINT ["java","-jar","/app.jar","--server.port=${APP_PORT}"]
