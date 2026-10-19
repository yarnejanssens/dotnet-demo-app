pipeline {
    agent any

    stages {
        // De broncode wordt door Jenkins automatisch uitgecheckt
        // (declaratieve pipeline met "Pipeline script from SCM").

        stage('Deploy') {
            steps {
                // Bouwt de image en (her)start database en applicatie
                sh 'bash ./deploy.sh'
            }
        }

        stage('Test') {
            steps {
                // Acceptatietest: de hoofdpagina leest uit de database, dus HTTP 200
                // betekent dat app en database samenwerken.
                // 172.17.0.1 = de Docker-host gezien vanuit de Jenkins-container.
                // Met retries, want de app heeft even nodig om op te starten.
                // Meer tijd om op te starten
                sleep(time: 30, unit: 'SECONDS')
                sh "curl -fsS --retry 10 --retry-delay 3 --retry-connrefused -o /dev/null -w 'HTTP %{http_code}\\n' http://172.17.0.1:5080/"
            }
        }
    }
}
