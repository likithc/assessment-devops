pipeline {
    agent any

    environment {
        // Registry and Image details
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'likithc/simple-java-app'
        IMAGE_TAG = "${env.BUILD_ID}"
        DOCKER_CREDENTIALS_ID = 'docker-cred'
    }

    stages {
        stage('SCM Pull') {
            steps {
                // Pulls the latest code from your repository
                checkout scm
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    // CRITICAL FIX: Empty string '' forces the correct default Docker Hub API endpoint
                    docker.withRegistry('', DOCKER_CREDENTIALS_ID) {
                        
                        // The multi-stage Dockerfile handles the Maven test & build internally.
                        // We build the image and assign it to a variable.
                        def customImage = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                        
                        // Push specific build tag
                        customImage.push()
                        // Push 'latest' tag
                        customImage.push('latest')
                    }
                }
            }
        }

        stage('Deploy via Docker Compose') {
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME}:${IMAGE_TAG}..."
                    // Explicitly export environment variables for docker-compose
                    sh "IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${IMAGE_TAG} APP_PORT=8080 docker-compose up -d --force-recreate"
                }
            }
        }

        stage('Verify Deployment (Curl Readiness)') {
            steps {
                // Readiness check without using 'sleep' commands
                timeout(time: 3, unit: 'MINUTES') {
                    retry(15) {
                        script {
                            // Adjust the port if your Java application listens on a different port (e.g., 80 vs 8080)
                            sh 'curl --silent --fail http://localhost:8080/ || exit 1'
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            // 1. Workspace Cleanup plugin step
            cleanWs()
            
            // 2. Clean up dangling resources to prevent disk space issues
            echo 'Cleaning up dangling Docker resources...'
            sh 'docker system prune -f --volumes'
            
            // 3. Remove the local copy of the image we just built
            sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            sh "docker rmi ${IMAGE_NAME}:latest || true"
        }
        success {
            echo "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_ID}]' completed successfully."
            
            // TODO: Uncomment once Slack authorization/plugin issues are resolved
            // slackSend channel: '#devops-alerts', color: 'good', message: "Deployment Successful: ${env.JOB_NAME} [${env.BUILD_ID}]"
        }
        failure {
            echo "FAILED: Job '${env.JOB_NAME} [${env.BUILD_ID}]'. Initiating rollback..."
            script {
                // Rollback logic: tear down the broken containers
                sh 'docker-compose down || true'
            }
            
            // TODO: Uncomment once Slack authorization/plugin issues are resolved
            // slackSend channel: '#devops-alerts', color: 'danger', message: "Deployment Failed: ${env.JOB_NAME} [${env.BUILD_ID}]"
        }
    }
}
