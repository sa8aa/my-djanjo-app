pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME = 'sa8aa/mydjango'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/sa8aa/my-djanjo-app.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                set -e
                python3 -m venv venv
                venv/bin/python -m pip install --upgrade pip
                venv/bin/python -m pip install -r requirements.txt
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                set -e
                venv/bin/python manage.py test
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $IMAGE_NAME:$BUILD_NUMBER .
                '''
            }
        }

        stage('Push to DockerHub') {
            steps {
                sh '''
                echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin
                docker push $IMAGE_NAME:$BUILD_NUMBER
                docker tag $IMAGE_NAME:$BUILD_NUMBER $IMAGE_NAME:latest
                docker push $IMAGE_NAME:latest
                '''
            }
        }
          stage('Push ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable: 'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS \
                            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        docker tag ${DOCKER_IMAGE}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                        docker tag ${DOCKER_IMAGE}:latest ${ECR_REPO}:latest

                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest

                        echo "✅ Image pushed to ECR : ${ECR_REPO}:${IMAGE_TAG}"
                    """
                }
            }
            post {
                success { echo "✅ ECR push successful : ${ECR_REPO}:${IMAGE_TAG}" }
                failure { echo "❌ ECR push failed" }
            }
        }
    }
}
