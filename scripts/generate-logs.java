///usr/bin/env jbang "$0" "$@" ; exit $?
//DEPS info.picocli:picocli:4.6.3
//DEPS com.google.code.gson:gson:2.10.1
//DEPS org.tinylog:tinylog-api:2.7.0
//DEPS org.tinylog:tinylog-impl:2.7.0
//JAVA 17

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.tinylog.Logger;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Mixin;
import picocli.CommandLine.Parameters;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.Callable;
import java.util.stream.IntStream;

@Command(name = "generate-logs", mixinStandardHelpOptions = true, version = "1.0",
        description = "Spring Boot JSON Lines Log Generator for Loki + Grafana stack",
        subcommands = {
                GenerateLogs.BatchCommand.class,
                GenerateLogs.ContinuousCommand.class,
                GenerateLogs.BurstCommand.class
        })
class GenerateLogs implements Callable<Integer> {

    static {
        // Configure tinylog format to display on a single line
        System.setProperty("tinylog.writer", "console");
        System.setProperty("tinylog.writer.format", "{date: yyyy-MM-dd HH:mm:ss.SSS} {level} [{thread}] {class} - {message}");
        System.setProperty("tinylog.writer.level", "info");
    }

    private static final Random random = new Random();
    private static final Gson gson = new GsonBuilder().disableHtmlEscaping().create();
    // Removed .env loading; path is provided via CLI mixin.

    public static void main(String... args) {
        System.exit(new CommandLine(new GenerateLogs()).execute(args));
    }

    @Override
    public Integer call() {
        new CommandLine(this).usage(System.out);
        return 0;
    }

    // Picocli mixin to provide a logs path for all commands
    static class LogPathMixin {
        @Option(names = {"-p", "--logs-path"}, paramLabel = "PATH",
                description = "Full path to the log folder (default: ../logs)",
                defaultValue = "../logs")
        String logsPath;
    }

    @Command(name = "batch", mixinStandardHelpOptions = true,
             description = "Generate a batch of log entries")
    static class BatchCommand implements Callable<Integer> {
        @Mixin
        LogPathMixin logPath;
        @Parameters(index = "0", description = "Number of logs to generate", defaultValue = "100")
        private int count;

        @Override
        public Integer call() throws IOException {
            var writer = new LogWriter(logPath.logsPath);
            Logger.info("Generating {} log entries to {}", count, writer.logFile());

            IntStream.range(0, count).forEach(i -> {
                writer.write(LogEntry.generate());
                if ((i + 1) % 10 == 0) {
                    Logger.info("Generated {}/{} logs", i + 1, count);
                }
            });

            Logger.info("Completed! Generated {} logs to {}", count, writer.logFile());
            return 0;
        }
    }

    @Command(name = "continuous", mixinStandardHelpOptions = true,
             description = "Generate logs continuously")
    static class ContinuousCommand implements Callable<Integer> {
        @Mixin
        LogPathMixin logPath;
        @Override
        public Integer call() {
            var writer = new LogWriter(logPath.logsPath);
            Logger.info("Generating logs continuously to {}", writer.logFile());
            Logger.info("Press Ctrl+C to stop");

            try {
                while (true) {
                    var entry = LogEntry.generate();
                    writer.write(entry);
                    ConsoleLogger.log(entry);
                    Thread.sleep((long) (random.nextDouble() * 1900 + 100));
                }
            } catch (InterruptedException e) {
                Logger.info("Stopped log generation");
                return 0;
            }
        }
    }

    @Command(name = "burst", mixinStandardHelpOptions = true,
             description = "Generate bursts of logs with pauses")
    static class BurstCommand implements Callable<Integer> {
        @Mixin
        LogPathMixin logPath;
        @Parameters(index = "0", description = "Number of bursts", defaultValue = "5")
        private int bursts;

        @Parameters(index = "1", description = "Logs per burst", defaultValue = "50")
        private int logsPerBurst;

        @Override
        public Integer call() throws Exception {
            var writer = new LogWriter(logPath.logsPath);
            Logger.info("Generating {} bursts of {} logs each", bursts, logsPerBurst);

            for (int burst = 0; burst < bursts; burst++) {
                Logger.info("Burst {}/{}", burst + 1, bursts);

                for (int i = 0; i < logsPerBurst; i++) {
                    writer.write(LogEntry.generate());
                    Thread.sleep(10);
                }

                if (burst < bursts - 1) {
                    Logger.info("Waiting 5 seconds before next burst...");
                    Thread.sleep(5000);
                }
            }

            Logger.info("Completed! Generated {} logs in {} bursts", bursts * logsPerBurst, bursts);
            return 0;
        }
    }

    record LogEntry(
            String ts,
            String level,
            String type,
            String application,
            String thread,
            String logger,
            String message,
            String traceId,
            String spanId,
            ExceptionInfo exception
    ) {
        static LogEntry generate() {
            var level = LogLevel.random();
            var timestamp = timestamp();
            var thread = ThreadName.random();
            var logger = LoggerName.random();
            var message = Message.generate(level);
            var traceId = random.nextDouble() < 0.5 ? TraceId.generate() : null;
            var spanId = traceId != null ? SpanId.generate() : null;
            var exception = level == LogLevel.ERROR && random.nextDouble() < 0.7
                    ? ExceptionInfo.generate() : null;

            return new LogEntry(timestamp, level.name(), level.name(), "demo-app",
                    thread, logger, message, traceId, spanId, exception);
        }

        private static String timestamp() {
            var bogotaZone = ZoneId.of("America/Bogota");
            var now = ZonedDateTime.now(bogotaZone);
            return now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSZZZ"));
        }
    }

    record ExceptionInfo(String className, String message, String stackTrace) {
        static ExceptionInfo generate() {
            var exClass = ExceptionClass.random();
            var exMessage = ExceptionMessage.generate();
            var stackTrace = String.format("%s: %s\n\tat com.example.demo.Example.method(Example.java:%d)\n\tat com.example.demo.Main.run(Main.java:%d)",
                    exClass, exMessage, random.nextInt(190) + 10, random.nextInt(90) + 10);

            return new ExceptionInfo(exClass, exMessage, stackTrace);
        }
    }

    enum LogLevel {
        INFO(60), DEBUG(20), WARN(15), ERROR(4), TRACE(1);

        private final int weight;

        LogLevel(int weight) {
            this.weight = weight;
        }

        static LogLevel random() {
            int total = 0;
            for (var level : values()) total += level.weight;

            int value = random.nextInt(total);
            int cumulative = 0;

            for (var level : values()) {
                cumulative += level.weight;
                if (value < cumulative) return level;
            }
            return INFO;
        }
    }

    static class Message {
        private static final Map<LogLevel, List<String>> templates = Map.of(
                LogLevel.INFO, List.of(
                        "Application started successfully",
                        "User logged in successfully",
                        "Order created with ID: {}",
                        "Payment processed successfully",
                        "Database connection established",
                        "Request completed in {}ms",
                        "New user registered: {}",
                        "Session created for user: {}",
                        "Cache refreshed successfully",
                        "Health check passed"
                ),
                LogLevel.DEBUG, List.of(
                        "Entering method: {}",
                        "Exiting method: {}",
                        "Query executed: SELECT * FROM users WHERE id = {}",
                        "Cache hit for key: {}",
                        "Validating request parameters",
                        "Processing request from IP: {}",
                        "Applying security filter",
                        "Deserializing JSON payload",
                        "Loading configuration from: {}",
                        "Initializing bean: {}"
                ),
                LogLevel.WARN, List.of(
                        "Slow query detected: took {}ms",
                        "Cache miss for key: {}",
                        "Deprecated API used: {}",
                        "Retry attempt {} for operation",
                        "Queue size approaching limit: {}",
                        "Connection pool utilization high: {}%",
                        "Session timeout for user: {}",
                        "Invalid input received: {}",
                        "Rate limit approaching for IP: {}",
                        "Configuration value missing, using default"
                ),
                LogLevel.ERROR, List.of(
                        "Failed to process payment: {}",
                        "Database connection error: {}",
                        "Authentication failed for user: {}",
                        "Unable to send email notification",
                        "External API call failed: {}",
                        "Invalid JSON payload received",
                        "Resource not found: {}",
                        "Permission denied for user: {}",
                        "Transaction rollback: {}",
                        "Unexpected exception: {}"
                ),
                LogLevel.TRACE, List.of(
                        "Method trace: {} with parameters: {}",
                        "SQL statement: {}",
                        "HTTP request headers: {}",
                        "Request body: {}",
                        "Response body: {}"
                )
        );

        static String generate(LogLevel level) {
            var template = randomFrom(templates.get(level));
            return formatTemplate(template);
        }

        private static String formatTemplate(String template) {
            if (!template.contains("{}")) return template;

            var result = template;
            while (result.contains("{}")) {
                result = result.replaceFirst("\\{}", generateValue(template));
            }
            return result;
        }

        private static String generateValue(String template) {
            var lower = template.toLowerCase();
            if (lower.contains("id")) return String.valueOf(random.nextInt(9000) + 1000);
            if (lower.contains("ms")) return String.valueOf(random.nextInt(1950) + 50);
            if (lower.contains("user")) return "user" + random.nextInt(100);
            if (template.contains("%")) return String.valueOf(random.nextInt(26) + 70);
            if (template.contains("IP")) return "192.168.1." + (random.nextInt(255) + 1);
            return randomFrom(List.of("alpha", "beta", "gamma", "delta"));
        }
    }

    static class LoggerName {
        private static final List<String> loggers = List.of(
                "com.example.demo.controller.UserController",
                "com.example.demo.service.UserService",
                "com.example.demo.repository.UserRepository",
                "com.example.demo.controller.OrderController",
                "com.example.demo.service.OrderService",
                "com.example.demo.service.PaymentService",
                "com.example.demo.security.AuthenticationFilter",
                "com.example.demo.config.DataSourceConfig",
                "org.springframework.web.servlet.DispatcherServlet",
                "org.springframework.boot.web.embedded.tomcat.TomcatWebServer"
        );

        static String random() {
            return randomFrom(loggers);
        }
    }

    static class ThreadName {
        private static final List<String> threads = List.of(
                "http-nio-8080-exec-1",
                "http-nio-8080-exec-2",
                "http-nio-8080-exec-3",
                "http-nio-8080-exec-4",
                "scheduling-1",
                "task-executor-1",
                "task-executor-2"
        );

        static String random() {
            return randomFrom(threads);
        }
    }

    static class TraceId {
        static String generate() {
            return randomHex(32);
        }
    }

    static class SpanId {
        static String generate() {
            return randomHex(16);
        }
    }

    static class ExceptionClass {
        private static final List<String> classes = List.of(
                "java.sql.SQLException",
                "org.springframework.web.client.HttpClientErrorException",
                "java.io.IOException",
                "java.lang.NullPointerException",
                "javax.validation.ValidationException",
                "org.springframework.security.access.AccessDeniedException",
                "com.example.demo.exception.ResourceNotFoundException",
                "com.example.demo.exception.PaymentException"
        );

        static String random() {
            return randomFrom(classes);
        }
    }

    static class ExceptionMessage {
        private static final List<String> messages = List.of(
                "Connection timeout after 30000ms",
                "Invalid credentials provided",
                "Resource with ID {} not found",
                "Payment gateway returned error code: {}",
                "Validation failed for field: {}",
                "Database constraint violation",
                "API rate limit exceeded",
                "Session expired"
        );

        static String generate() {
            var template = randomFrom(messages);
            return template.contains("{}")
                    ? template.replace("{}", String.valueOf(random.nextInt(9000) + 1000))
                    : template;
        }
    }

    static class LogWriter {
        private final Path logFile;

        LogWriter(String logDir) {
            var logPath = Paths.get(logDir);

            try {
                if (!Files.exists(logPath)) {
                    Files.createDirectories(logPath);
                    Logger.info("Created directory: {}", logDir);
                }
            } catch (IOException e) {
                throw new RuntimeException("Failed to create log directory: " + logDir, e);
            }

            this.logFile = logPath.resolve("application.log");
        }

        void write(LogEntry entry) {
            try {
                var json = gson.toJson(entry) + "\n";
                Files.writeString(logFile, json,
                        StandardOpenOption.CREATE,
                        StandardOpenOption.APPEND);
            } catch (IOException e) {
                Logger.error(e, "Failed to write log");
            }
        }

        String logFile() {
            return logFile.toString();
        }
    }

    static class ConsoleLogger {
        private static final Map<String, String> colors = Map.of(
                "INFO", "\033[32m",
                "DEBUG", "\033[36m",
                "WARN", "\033[33m",
                "ERROR", "\033[31m",
                "TRACE", "\033[37m"
        );
        private static final String reset = "\033[0m";

        static void log(LogEntry entry) {
            var color = colors.getOrDefault(entry.level(), "");
            var formatted = String.format("%s[%-5s] %-50s - %s%s",
                    color, entry.level(), entry.logger(), entry.message(), reset);
            Logger.info(formatted);
        }
    }

    private static <T> T randomFrom(List<T> list) {
        return list.get(random.nextInt(list.size()));
    }

    private static String randomHex(int length) {
        return IntStream.range(0, length)
                .mapToObj(i -> Integer.toHexString(random.nextInt(16)))
                .reduce("", String::concat);
    }
}
