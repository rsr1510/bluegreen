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
                echo '📦 Checking out repository...'
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "🔧 Building Docker image version ${APP_VERSION}"
                    sh """
                        docker build -t ${IMAGE_NAME}:${APP_VERSION} .
                        docker tag ${IMAGE_NAME}:${APP_VERSION} ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    echo '📤 Pushing image to Docker Hub...'
                    sh """
                        echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin
                        docker push ${IMAGE_NAME}:${APP_VERSION}
                        docker push ${IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Determine Active Environment') {
            steps {
                script {
                    echo '🔍 Determining active environment...'
                    def nginxConfig = readFile('nginx/nginx.conf')
                    if (nginxConfig.contains('server blue-app:3000')) {
                        env.ACTIVE_ENV = 'blue'
                        env.TARGET_ENV = 'green'
                    } else {
                        env.ACTIVE_ENV = 'green'
                        env.TARGET_ENV = 'blue'
                    }
                    echo "🔵 Active: ${env.ACTIVE_ENV}, 🟢 Target: ${env.TARGET_ENV}"
                }
            }
        }

        stage('Deploy to Inactive Environment') {
            steps {
                script {
                    echo "🚀 Deploying version ${APP_VERSION} to ${TARGET_ENV} environment..."
                    sh """
                        export VERSION=${APP_VERSION}
                        export DOCKER_USERNAME=${DOCKER_USERNAME}

                        echo "🧹 Cleaning up any old ${TARGET_ENV} containers..."
                        docker-compose -f docker-compose.${TARGET_ENV}.yml down -v --remove-orphans || true
                        docker rm -f ${TARGET_ENV}-app || true
                        docker network prune -f || true

                        echo "🚀 Starting ${TARGET_ENV}-app fresh..."
                        docker-compose -f docker-compose.${TARGET_ENV}.yml pull
                        docker-compose -f docker-compose.${TARGET_ENV}.yml up -d --force-recreate
                    """
                }
            }
        }

        stage('Health Check') {
        steps {
            script {
                echo '💚 Performing health check inside target container...'
                sh '''
                    #!/bin/bash
                    echo "Starting health check for ${TARGET_ENV}-app..."

                    for i in {1..10}; do
                        docker-compose -f docker-compose.${TARGET_ENV}.yml exec -T ${TARGET_ENV}-app sh -c "curl -s -f http://localhost:3000/health" && {
                            echo "✅ Health check passed inside ${TARGET_ENV}-app!";
                            exit 0;
                        }
                        echo "Waiting for ${TARGET_ENV}-app to be ready... ($i/10)";
                        sleep 5;
                    done

                    echo "❌ Health check failed after multiple attempts.";
                    exit 1
                '''
                }
            }
    }



        stage('Switch Traffic') {
            steps {
                script {
                    echo "🔁 Switching traffic to ${TARGET_ENV}..."
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
                    echo "🧪 Verifying deployment (v${APP_VERSION})..."
                    sh "curl -f http://localhost:8080/"
                    echo "✅ Deployment successful — zero downtime maintained!"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment complete — version ${APP_VERSION} is live on ${TARGET_ENV}"
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
                    echo "⚠️ Rollback skipped — ACTIVE_ENV not set."
                }
            }
        }
        always {
            sh "docker logout || true"
        }
    }
}
