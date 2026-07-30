pipeline {
    agent any

    // Define pipeline variables
    environment {
        DOCKER_REGISTRY = 'my-private-registry.com'
        DOCKER_CREDENTIALS_ID = 'private-registry-creds' 
        GITHUB_CREDENTIALS_ID = 'github-repo-creds'      
        IMAGE_NAME = 'my-company/simple-java-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"                
        APP_PORT = '8080'
        SLACK_CHANNEL = '#deployments'
    }

    stages {
        stage('SCM Pull') {
            steps {
                // Checkout code from the private GitHub repository
                checkout scm
                echo "Code checked out successfully."
            }
        }

        stage('Install Dependencies and Run Tests') {
            steps {
                // Using a temporary Maven container for isolated testing
                script {
                    docker.image('maven:3.9-eclipse-temurin-17-alpine').inside {
                        sh 'mvn test'
                    }
                }
            }
        }

        stage('Build & Push Docker Image') {
            steps {
                script {
                    // Authenticate with private registry
                    docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDENTIALS_ID) {
                        // Build the multi-stage Docker image
                        def customImage = docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
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
                    // Pull the new image and recreate the container
                    sh "IMAGE_TAG=${IMAGE_TAG} docker-compose pull"
                    sh "IMAGE_TAG=${IMAGE_TAG} docker-compose up -d --force-recreate"
                }
            }
        }

        stage('Verify Deployment (Curl Readiness)') {
            steps {
                script {
                    echo "Waiting for Java application to become healthy..."
                    // Readiness wait logic: Retries curl every 5 seconds for up to 2 minutes
                    timeout(time: 2, unit: 'MINUTES') {
                        waitUntil {
                            def status = sh(
                                script: "curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}/health || true", 
                                returnStdout: true
                            ).trim()
                            
                            if (status == '200') {
                                echo "Application is up and returning 200 OK."
                                return true
                            } else {
                                echo "Endpoint returned HTTP ${status}. Retrying..."
                                sleep 5
                                return false
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(channel: "${SLACK_CHANNEL}", color: 'good', message: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' deployed successfully.")
        }
        failure {
            slackSend(channel: "${SLACK_CHANNEL}", color: 'danger', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'. Initiating rollback...")
            
            // Rollback Support: Redeploy previous successful image
            script {
                def prevBuild = currentBuild.previousSuccessfulBuild
                if (prevBuild) {
                    def PREV_TAG = prevBuild.number
                    echo "Rolling back to previous successful build: ${PREV_TAG}"
                    sh "IMAGE_TAG=${PREV_TAG} docker-compose up -d --force-recreate"
                } else {
                    echo "No previous successful build found. Rollback aborted."
                }
            }
        }
        always {
            // Clean up workspace
            cleanWs()
            
            // Clean up dangling resources and old builds
            echo "Cleaning up dangling Docker resources..."
            sh 'docker system prune -f --volumes'
            
            // Remove local image to save disk space 
            sh "docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true"
        }
    }
}
