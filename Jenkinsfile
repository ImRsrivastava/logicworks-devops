pipeline {
    agent any

    environment {
        PRIMARY_REGION   = "ap-south-1"
        SECONDARY_REGION = "us-east-1"
        ACCOUNT_ID       = "YOUR_AWS_ACCOUNT_ID"
        REPO_NAME        = "logicworks-devops-api"
        PRIMARY_CLUSTER  = "logicworks-devops-primary-cluster"
        SECONDARY_CLUSTER= "logicworks-devops-secondary-cluster"
        STAGING_SERVICE  = "logicworks-devops-staging-svc"
        PROD_SERVICE     = "logicworks-devops-prod-svc"
        DR_PROD_SERVICE  = "logicworks-devops-prod-dr-svc"
    }

    stages {
        stage('Source Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/YOUR_USERNAME/logicworks-devops.git'
            }
        }

        stage('Build & Push Docker Image (Multi-Region)') {
            steps {
                sh '''
                    IMAGE_TAG=${BUILD_NUMBER}
                    PRIMARY_ECR="${ACCOUNT_ID}.dkr.ecr.${PRIMARY_REGION}.amazonaws.com/${REPO_NAME}"
                    SECONDARY_ECR="${ACCOUNT_ID}.dkr.ecr.${SECONDARY_REGION}.amazonaws.com/${REPO_NAME}"

                    aws ecr get-login-password --region ${PRIMARY_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${PRIMARY_REGION}.amazonaws.com
                    aws ecr get-login-password --region ${SECONDARY_REGION} | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${SECONDARY_REGION}.amazonaws.com

                    docker build -t ${PRIMARY_ECR}:${IMAGE_TAG} -t ${PRIMARY_ECR}:latest ./app
                    docker push ${PRIMARY_ECR}:${IMAGE_TAG}
                    docker push ${PRIMARY_ECR}:latest

                    docker tag ${PRIMARY_ECR}:${IMAGE_TAG} ${SECONDARY_ECR}:${IMAGE_TAG}
                    docker tag ${PRIMARY_ECR}:latest ${SECONDARY_ECR}:latest
                    docker push ${SECONDARY_ECR}:${IMAGE_TAG}
                    docker push ${SECONDARY_ECR}:latest
                '''
            }
        }

        stage('Deploy to Staging') {
            steps {
                sh '''
                    aws ecs update-service \
                      --region ${PRIMARY_REGION} \
                      --cluster ${PRIMARY_CLUSTER} \
                      --service ${STAGING_SERVICE} \
                      --force-new-deployment
                '''
            }
        }

        stage('Manual Approval for Production') {
            steps {
                input message: 'Staging verified! Approve deployment to Production (Primary + DR)?', ok: 'Approve & Deploy'
            }
        }

        stage('Deploy to Production (Primary + DR)') {
            steps {
                sh '''
                    aws ecs update-service \
                      --region ${PRIMARY_REGION} \
                      --cluster ${PRIMARY_CLUSTER} \
                      --service ${PROD_SERVICE} \
                      --force-new-deployment

                    aws ecs update-service \
                      --region ${SECONDARY_REGION} \
                      --cluster ${SECONDARY_CLUSTER} \
                      --service ${DR_PROD_SERVICE} \
                      --force-new-deployment
                '''
            }
        }
    }
}