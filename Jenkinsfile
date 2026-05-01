pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME            = 'sa8aa/my-djanjo-app'

        // AWS / ECR
        AWS_REGION     = 'us-east-1'
        AWS_ACCOUNT_ID = '271744664756'
        ECR_REPO       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/my-djanjo-app"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        KEY_NAME       = 'vockey'
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
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
            }
        }

        stage('Push to DockerHub') {
            steps {
                sh '''
                    echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin
                    docker push $IMAGE_NAME:$IMAGE_TAG
                    docker tag  $IMAGE_NAME:$IMAGE_TAG $IMAGE_NAME:latest
                    docker push $IMAGE_NAME:latest
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId:    'aws-credentials',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    string(
                        credentialsId: 'aws-session-token',
                        variable:      'AWS_SESSION_TOKEN'
                    )
                ]) {
                    sh """
                        export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        # ── Create ECR repo if it doesn't exist ──────────────
                        aws ecr describe-repositories \
                            --repository-names my-djanjo-app \
                            --region ${AWS_REGION} 2>/dev/null || \
                        aws ecr create-repository \
                            --repository-name my-djanjo-app \
                            --region ${AWS_REGION}

                        # ── Login to ECR ──────────────────────────────────────
