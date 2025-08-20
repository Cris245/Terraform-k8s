package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	httpRequestsInFlight = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_requests_in_flight",
			Help: "Current number of HTTP requests being processed",
		},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(httpRequestsInFlight)
}

func appHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	// Increment in-flight requests
	httpRequestsInFlight.Inc()
	defer httpRequestsInFlight.Dec()

	// Log request
	log.Printf("%s %s %s", time.Now().Format("2006-01-02 15:04:05"), r.Method, r.URL.Path)

	// Set response headers
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("X-Server", "Golang-HA-Server")
	w.Header().Set("X-Version", "1.0.0")

	// Generate response
	response := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>Golang HA Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; background: rgba(255,255,255,0.1); padding: 30px; border-radius: 10px; backdrop-filter: blur(10px); }
        h1 { color: #fff; text-align: center; margin-bottom: 30px; }
        .info { background: rgba(255,255,255,0.2); padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: rgba(255,255,255,0.1); border-radius: 5px; }
        .status { color: #4CAF50; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Golang High Availability Server</h1>
        <div class="info">
            <h2>Server Information</h2>
            <div class="metric">
                <strong>Timestamp:</strong> %s
            </div>
            <div class="metric">
                <strong>Status:</strong> <span class="status">✅ Healthy</span>
            </div>
            <div class="metric">
                <strong>Version:</strong> 1.0.0
            </div>
            <div class="metric">
                <strong>Environment:</strong> %s
            </div>
        </div>
        <div class="info">
            <h2>Request Details</h2>
            <div class="metric">
                <strong>Method:</strong> %s
            </div>
            <div class="metric">
                <strong>Path:</strong> %s
            </div>
            <div class="metric">
                <strong>User Agent:</strong> %s
            </div>
            <div class="metric">
                <strong>Remote Address:</strong> %s
            </div>
        </div>
        <div class="info">
            <h2>System Information</h2>
            <div class="metric">
                <strong>Hostname:</strong> %s
            </div>
            <div class="metric">
                <strong>Uptime:</strong> %s
            </div>
        </div>
    </div>
</body>
</html>`,
		time.Now().Format("2006-01-02 15:04:05"),
		getEnv("ENVIRONMENT", "production"),
		r.Method,
		r.URL.Path,
		r.UserAgent(),
		r.RemoteAddr,
		getEnv("HOSTNAME", "unknown"),
		time.Since(start).String(),
	)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(response))

	// Record metrics
	duration := time.Since(start).Seconds()
	httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, "200").Inc()
	httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"healthy","timestamp":"` + time.Now().Format(time.RFC3339) + `"}`))
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	promhttp.Handler().ServeHTTP(w, r)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func main() {
	port := getEnv("PORT", "8080")

	log.Printf("🚀 Starting Golang HA Server on port %s", port)
	log.Printf("📊 Environment: %s", getEnv("ENVIRONMENT", "production"))
	log.Printf("🏠 Hostname: %s", getEnv("HOSTNAME", "unknown"))

	// Register handlers
	http.HandleFunc("/", appHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/metrics", metricsHandler)

	// Start server
	log.Printf("✅ Server started, serving on port %s", port)
	log.Printf("📈 Metrics available at http://localhost:%s/metrics", port)
	log.Printf("❤️  Health check available at http://localhost:%s/health", port)

	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatal("❌ Server failed to start: ", err.Error())
	}
}
