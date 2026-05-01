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
        KEY_NAME       = 'vockey'                        // ← AWS Academy default key name
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
                        AWS_PASS=\$(aws ecr get-login-password --region ${AWS_REGION})
                        echo "\$AWS_PASS" | docker login \
                            --username AWS \
                            --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                        # ── Tag and push ───────────────────────────────────────
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_REPO}:latest
                        docker push ${ECR_REPO}:${IMAGE_TAG}
                        docker push ${ECR_REPO}:latest

                        echo "✅ Image pushed to ECR: ${ECR_REPO}:${IMAGE_TAG}"
                    """
                }
            }
            post {
                success { echo "✅ ECR push successful: ${ECR_REPO}:${IMAGE_TAG}" }
                failure { echo "❌ ECR push failed" }
            }
        }

        stage('Provision Infra') {
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
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {
                    sh """
                        export AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
                        export AWS_SESSION_TOKEN=\${AWS_SESSION_TOKEN}

                        # ── Check if stack already exists ──────────────────
                        STACK_STATUS=\$(aws cloudformation describe-stacks \\
                            --stack-name my-djanjo-app-infra \\
                            --region ${AWS_REGION} \\
                            --query 'Stacks[0].StackStatus' \\
                            --output text 2>/dev/null || echo "DOES_NOT_EXIST")

                        echo "Stack status: \$STACK_STATUS"

                        if [ "\$STACK_STATUS" = "DOES_NOT_EXIST" ]; then
                            echo "Creating stack..."
                            aws cloudformation create-stack \\
                                --stack-name my-djanjo-app-infra \\
                                --template-body file://cloudformation/infra-stack.yaml \\
                                --parameters \\
                                    ParameterKey=ProjectName,ParameterValue=my-djanjo-app \\
                                    ParameterKey=KeyName,ParameterValue=${KEY_NAME} \\
                                --region ${AWS_REGION}

                            echo "Waiting for stack creation..."
                            aws cloudformation wait stack-create-complete \\
                                --stack-name my-djanjo-app-infra \\
                                --region ${AWS_REGION}

                        elif [ "\$STACK_STATUS" = "CREATE_COMPLETE" ] || \\
                             [ "\$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
                            echo "Stack already exists — skipping creation"

                        else
                            echo "Stack in unexpected status: \$STACK_STATUS"
                            exit 1
                        fi

                        # ── Get EC2 public IP ──────────────────────────────
                        EC2_IP=\$(aws cloudformation describe-stacks \\
                            --stack-name my-djanjo-app-infra \\
                            --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIP`].OutputValue' \\
                            --output text \\
                            --region ${AWS_REGION})

                        echo "EC2 IP: \$EC2_IP"
                        echo \$EC2_IP > /tmp/ec2-ip.txt

                        # ── Wait for k3s to be ready (max 5 min) ──────────
                        echo "Waiting for k3s to be ready..."
                        chmod 400 \${SSH_KEY}

                        for i in \$(seq 1 30); do
                            STATUS=\$(ssh -i \${SSH_KEY} \\
                                -o StrictHostKeyChecking=no \\
                                -o ConnectTimeout=10 \\
                                ec2-user@\$EC2_IP \\
                                "sudo kubectl get nodes 2>/dev/null | grep Ready || echo NOT_READY")

                            if echo "\$STATUS" | grep -q "Ready"; then
                                echo "✅ k3s is ready: \$STATUS"
                                break
                            fi

                            echo "Attempt \$i/30 — k3s not ready yet, waiting 10s..."
                            sleep 10

                            if [ \$i -eq 30 ]; then
                                echo "❌ k3s did not become ready in time"
                                exit 1
                            fi
                        done

                        echo "✅ Infrastructure provisioned and k3s ready at: \$EC2_IP"
                    """
                }
            }
            post {
                success { echo "✅ Infrastructure provisioned successfully" }
                failure { echo "❌ CloudFormation or k3s setup failed" }
            }
        }

    }

    post {
        always {
            sh 'docker logout || true'
            cleanWs()
        }
        success { echo "🚀 Pipeline completed successfully." }
        failure { echo "💥 Pipeline failed." }
    }
}
