pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'likithc/simple-java-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'docker-cred'
        APP_PORT = '7070' // Configured to avoid Jenkins port 8080 conflict
    }

    stages {
        stage('SCM Pull') {
            steps {
                checkout scm
                echo "Code checked out successfully."
            }
        }

        stage('Install Dependencies and Run Tests') {
            steps {
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
                    docker.withRegistry('', DOCKER_CREDENTIALS_ID) {
                        def customImage = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                        customImage.push()
                        customImage.push('latest')
                    }
                }
            }
        }

        stage('Deploy via Docker Compose') {
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME}:${IMAGE_TAG} on port ${APP_PORT}..."
                    sh "IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${IMAGE_TAG} APP_PORT=${APP_PORT} docker-compose up -d --force-recreate"
                }
            }
        }

        stage('Deploy via Docker Compose') {
            steps {
                script {
                    echo "Deploying ${IMAGE_NAME}:${IMAGE_TAG} on port ${APP_PORT}..."
                    // Stop any existing container cleanly to avoid the ContainerConfig bug
                    sh "IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${IMAGE_TAG} APP_PORT=${APP_PORT} docker-compose down || true"
                    // Bring up the new container fresh
                    sh "IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${IMAGE_TAG} APP_PORT=${APP_PORT} docker-compose up -d"
                }
            }
        }

    post {
        success {
            echo "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' deployed successfully."
        }
        failure {
            echo "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'. Initiating rollback..."
            script {
                def prevBuild = currentBuild.previousSuccessfulBuild
                if (prevBuild) {
                    def PREV_TAG = prevBuild.number
                    echo "Rolling back to previous successful build tag: ${PREV_TAG}"
                    sh "IMAGE_NAME=${IMAGE_NAME} IMAGE_TAG=${PREV_TAG} APP_PORT=${APP_PORT} docker-compose up -d --force-recreate"
                } else {
                    echo "No previous successful build found. Rollback aborted."
                }
            }
        }
        always {
            cleanWs()
            echo "Cleaning up dangling Docker resources..."
            sh 'docker system prune -f --volumes'
            sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            sh "docker rmi ${IMAGE_NAME}:latest || true"
        }
    }
}
