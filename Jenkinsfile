pipeline {
    agent any

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
                venv/bin/pip install --upgrade pip
                venv/bin/pip install -r requirements.txt
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
    }
}
