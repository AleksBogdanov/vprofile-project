FROM openjdk:11 AS BUILD_IMAGE
RUN apt-get update && apt-get install -y maven git
RUN git clone https://github.com/AleksBogdanov/vprofile-project.git
RUN cd vprofile-project && git checkout docker && mvn install

FROM tomcat:9-jre11
LABEL "Project"="vprofile"
LABEL "Author"="Aleks"
RUN rm -rf /usr/local/tomcat/webapps/*
COPY --from=BUILD_IMAGE vprofile-project/target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]