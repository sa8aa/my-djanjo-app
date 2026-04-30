pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')
        IMAGE_NAME = 'your-dockerhub-username/mydjango'
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
    }
}
