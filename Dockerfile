
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /usr/src/app


COPY pom.xml ./
RUN mvn dependency:go-offline -B


COPY . .


RUN mvn clean package -DskipTests


FROM eclipse-temurin:17-jre-alpine AS production

WORKDIR /usr/src/app

RUN apk add --no-cache curl


RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser


COPY --from=builder --chown=appuser:appgroup /usr/src/app/target/*.jar app.jar


EXPOSE 8080


HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["java", "-jar", "app.jar"]
