pipeline {
    agent any

    environment {
        DOCKER_USERNAME = credentials('docker-hub-username')
        DOCKER_PASSWORD = credentials('docker-hub-password')
        APP_VERSION = "${BUILD_NUMBER}"
        IMAGE_NAME = "${DOCKER_USERNAME}/blue-green-app"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image version ${APP_VERSION}"
                    sh "docker build -t ${IMAGE_NAME}:${APP_VERSION} ."
                    sh "docker tag ${IMAGE_NAME}:${APP_VERSION} ${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "Pushing image to Docker Hub..."
                    sh "echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin"
                    sh "docker push ${IMAGE_NAME}:${APP_VERSION}"
                    sh "docker push ${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Determine Active Environment') {
            steps {
                script {
                    def nginxConfig = readFile('nginx/nginx.conf')
                    if (nginxConfig.contains('server blue-app:3000')) {
                        env.ACTIVE_ENV = 'blue'
                        env.TARGET_ENV = 'green'
                    } else {
                        env.ACTIVE_ENV = 'green'
                        env.TARGET_ENV = 'blue'
                    }
                    echo "Active: ${env.ACTIVE_ENV}, Target: ${env.TARGET_ENV}"
                }
            }
        }

        stage('Deploy to Inactive Environment') {
            steps {
                script {
                    echo "Deploying version ${APP_VERSION} to ${TARGET_ENV}"
                    sh """
                        export VERSION=${APP_VERSION}
                        export DOCKER_USERNAME=${DOCKER_USERNAME}
                        docker-compose -f docker-compose.${TARGET_ENV}.yml down
                        docker-compose -f docker-compose.${TARGET_ENV}.yml pull
                        docker-compose -f docker-compose.${TARGET_ENV}.yml up -d
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "Running health check..."
                    def port = (env.TARGET_ENV == 'blue') ? '3001' : '3002'
                    retry(5) {
                        sleep 5
                        sh "curl -f http://localhost:${port}/health"
                    }
                    echo "Health check passed on ${TARGET_ENV}"
                }
            }
        }

        stage('Switch Traffic') {
            steps {
                script {
                    echo "Switching traffic to ${TARGET_ENV}"
                    if (env.TARGET_ENV == 'blue') {
                        sh "bash scripts/switch-to-blue.sh"
                    } else {
                        sh "bash scripts/switch-to-green.sh"
                    }
                    sleep 5
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    sh "curl -f http://localhost:8080/"
                    echo "Traffic successfully switched!"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment complete — Version ${APP_VERSION} is live on ${TARGET_ENV}"
        }
        failure {
            echo "❌ Deployment failed — rolling back..."
            script {
                if (env.ACTIVE_ENV) {
                    if (env.ACTIVE_ENV == 'blue') {
                        sh "bash scripts/switch-to-blue.sh"
                    } else {
                        sh "bash scripts/switch-to-green.sh"
                    }
                } else {
                    echo "Rollback skipped — ACTIVE_ENV not set."
                }
            }
        }
        always {
            sh "docker logout"
        }
    }
}
