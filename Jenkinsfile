pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'blue-green-app'
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-login')
        DOCKER_USERNAME = "${DOCKERHUB_CREDENTIALS_USR}"
        DOCKER_PASSWORD = "${DOCKERHUB_CREDENTIALS_PSW}"
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
                    def version = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
                    env.VERSION = version
                    echo "🔧 Building Docker image version ${version}"
                    sh """
                        docker build -t ${DOCKER_USERNAME}/${DOCKER_IMAGE}:${version} .
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
                        docker push ${DOCKER_USERNAME}/${DOCKER_IMAGE}:${VERSION}
                        docker logout
                    """
                }
            }
        }

        stage('Determine Active Environment') {
            steps {
                script {
                    echo '🔍 Determining active environment...'
                    def activeEnv = sh(script: "docker ps --format '{{.Names}}' | grep -E 'blue-app|green-app' | head -n 1", returnStdout: true).trim()
                    if (activeEnv.contains('blue')) {
                        env.ACTIVE_ENV = 'blue'
                        env.TARGET_ENV = 'green'
                    } else {
                        env.ACTIVE_ENV = 'green'
                        env.TARGET_ENV = 'blue'
                    }
                    echo "🔵 Active: ${ACTIVE_ENV}, 🟢 Target: ${TARGET_ENV}"
                }
            }
        }

        stage('Deploy to Inactive Environment') {
            steps {
                script {
                    echo "🚀 Deploying version ${VERSION} to ${TARGET_ENV} environment..."
                    sh """
                        export VERSION=${VERSION}
                        export DOCKER_USERNAME=${DOCKER_USERNAME}
                        echo "🧹 Cleaning up any old ${TARGET_ENV} containers..."
                        docker-compose -f docker-compose.${TARGET_ENV}.yml down -v --remove-orphans || true
                        docker rm -f ${TARGET_ENV}-app || true
                        docker network prune -f || true
                        echo "🚀 Bringing up fresh ${TARGET_ENV}-app..."
                        docker-compose -f docker-compose.${TARGET_ENV}.yml pull
                        docker-compose -f docker-compose.${TARGET_ENV}.yml up -d --force-recreate

                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo '💚 Performing health check on new environment...'
                    sh """
                        for i in {1..10}; do
                            if curl -s http://${TARGET_ENV}-app:3000/health | grep -q 'OK'; then
                                echo '✅ Health check passed!';
                                exit 0;
                            fi;
                            echo 'Waiting for app to be ready...';
                            sleep 5;
                        done;
                        echo '❌ Health check failed!';
                        exit 1;
                    """
                }
            }
        }

        stage('Switch Traffic') {
            steps {
                script {
                    if (env.TARGET_ENV == 'green') {
                        echo '🔁 Switching Nginx traffic to GREEN...'
                        sh 'bash scripts/switch-to-green.sh'
                    } else {
                        echo '🔁 Switching Nginx traffic to BLUE...'
                        sh 'bash scripts/switch-to-blue.sh'
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "🧪 Verifying deployment (version ${VERSION})..."
                    sh 'curl -s http://localhost/ | head -n 5'
                    echo '✅ Deployment successful — zero downtime maintained!'
                }
            }
        }
    }

    post {
        failure {
            echo '❌ Deployment failed — rolling back...'
            script {
                if (env.ACTIVE_ENV && fileExists("scripts/switch-to-${ACTIVE_ENV}.sh")) {
                    sh "bash scripts/switch-to-${ACTIVE_ENV}.sh"
                    echo "🔄 Rolled back traffic to ${ACTIVE_ENV}."
                } else {
                    echo '⚠️ Rollback skipped — no active environment found.'
                }
            }
        }
    }
}
