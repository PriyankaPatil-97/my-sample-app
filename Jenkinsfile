pipeline {
  agent any

  environment {
    AWS_ACCOUNT_ID = "676206916950"
    AWS_REGION = "ap-south-1"
    ECR_REPO = "my-sample-app"
    IMAGE_NAME = "${ECR_REPO}"
    IMAGE_TAG = "${env.BUILD_NUMBER}"
  }

  tools { maven "Maven" }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build (package)') {
      steps { sh 'mvn -B -DskipTests clean package' }
    }

    stage('Unit Tests') {
      steps {
        sh 'mvn -B test'
        junit '**/target/surefire-reports/*.xml'
      }
    }

    stage('SonarQube Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          withSonarQubeEnv('SonarQube') {
            sh 'mvn -B sonar:sonar -Dsonar.login=$SONAR_TOKEN'
          }
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          script {
            def qg = waitForQualityGate()
            echo "Quality gate status: ${qg.status}"
            if (qg.status != 'OK') {
              error "Quality Gate failed: ${qg.status}"
            }
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
      }
    }

    stage('Trivy - image scan') {
      steps {
        // fails pipeline on HIGH or CRITICAL; remove --exit-code or change to 0 to only warn
        sh """
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image --exit-code 1 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
        """
      }
    }

    stage('Push to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh """
            # configure aws cli temporarily
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            aws configure set default.region ${AWS_REGION}

            # login
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

            # create repo if missing
            aws ecr create-repository --repository-name ${ECR_REPO} || true

            # tag & push
            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}
            docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('Deploy') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh """
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
            docker rm -f ${IMAGE_NAME} || true
            docker run -d -p 8080:8080 --name ${IMAGE_NAME} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}
          """
        }
      }
    }
  }

  post {
    always { archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: true }
    failure { echo "Build failed. Check the console output." }
  }
}
