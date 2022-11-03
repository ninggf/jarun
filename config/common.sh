## Adjust memory settings if necessary
#JAVA_OPTS="-Xms256m -Xmx1G -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=4096m -XX:MaxNewSize=4096m -XX:SurvivorRatio=8"
#JAVA_OPTS="-Xms256m -Xmx1G"

## Adjust gc options is necessary
#JVM_GC_OPTS="-XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:${LOG_DIR}/${SERVICE_NAME}.gc"

## Adjust oom dump options if necessary
#JVM_OOM_OPTS="-XX:+HeapDumpOnOutOfMemoryError -XX:-OmitStackTraceInFastThrow -XX:HeapDumpPath==${LOG_DIR}/${SERVICE_NAME}.hprof"

# logback config
#LOGBACK_CONFIG="-Dlogging.config=${APP_PATH}/config/logback-spring.xml"

# prometheus agent
#PROMETHEUS_AGENT="-javaagent:prometheus_javaagent.jar=${PROMETHEUS_AGENT_PORT}:config.yaml"

# SKYWALKING AGENT
#SKYWALKING_AGENT="-javaagent:skywalking-agent.jar -Dskywalking.agent.service_name={$APP_ENV:-dev}::${SERVICE_NAME}"
