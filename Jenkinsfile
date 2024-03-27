pipeline {
    agent none

    environment {
        DOCKER_IMAGE = "ndminh1212/osm-server"
    }

    stages {
        stage("Clone stage") {
            git credentialsId: 'osm-server', url: 'https://github.com/dukeb1212/osm-server-docker.git'
        }
        stage("Build stage") {
            withDockerRegistry(credentialsId: 'docker-hub', url: 'https://index.docker.io/v1/') {
                sh 'docker build -t ndminh1212/osm-server:latest .'
                sh 'docker push ndminh1212/osm-server:latest'
            }
        }
    }
}