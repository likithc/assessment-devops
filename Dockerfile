# ==========================================
# Stage 1: Builder (Install dependencies & Build)
# ==========================================
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /usr/src/app

# Cache optimization: Copy pom.xml first to download dependencies
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# Copy the rest of the source code (including SimpleApp.java)
COPY . .

# Package the application (skipping tests here as Jenkins will handle them)
RUN mvn clean package -DskipTests

# ==========================================
# Stage 2: Production (Minimal Image & Security)
# ==========================================
FROM eclipse-temurin:17-jre-alpine AS production

WORKDIR /usr/src/app

# Install curl for the healthcheck requirement
RUN apk add --no-cache curl

# Enforce security: Create and use a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy the compiled JAR file from the builder stage
# (Maven typically outputs to the target directory. Adjust the wildcard if your pom.xml specifies a different final name)
COPY --from=builder --chown=appuser:appgroup /usr/src/app/target/*.jar app.jar

# Expose application port
EXPOSE 8080

# Define the healthcheck 
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Start the Java application
CMD ["java", "-jar", "app.jar"]
