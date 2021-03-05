package main


import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"
)

var (
	listenFlag  = flag.String("listen", ":5678", "address and port to listen")
	textFlag    = flag.String("text", "", "text to put on the webpage")

	version = "v0.0.0"
)

func main() {
	flag.Parse()

	// Validation
	if *textFlag == "" {
		fmt.Fprintln(os.Stderr, "Missing -text option!")
		os.Exit(127)
	}

	args := flag.Args()
	if len(args) > 0 {
		fmt.Fprintln(os.Stderr, "Too many arguments!")
		os.Exit(127)
	}

	// Flag gets printed as a page
	mux := http.NewServeMux()
	mux.HandleFunc("/echo", func(writer http.ResponseWriter, request *http.Request) {
		echoText := request.URL.Query()["text"]
		text := fmt.Sprintf(`
<!DOCTYPE html>
<html>
	<head>
		<title>Success</title>
	</head>
	<body>
		<p>Text: %s</p>
		<p>Version: %s</p>
	</body>
</html>
`, echoText, version)
		writer.Write([]byte(text))
	})
	mux.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		text := fmt.Sprintf(`
<!DOCTYPE html>
<html>
	<head>
		<title>Success</title>
	</head>
	<body>
		<p>Text: %s</p>
		<p>Version: %s</p>
	</body>
</html>
`, *textFlag, version)
		writer.Write([]byte(text))
	})

	// Health endpoint
	mux.HandleFunc("/health", func(writer http.ResponseWriter, request *http.Request) {
		writer.Write([]byte("OK"))
	})

	log.Printf("[INFO] Starting echo-server with version %s", version)
	server := &http.Server{
		Addr:    *listenFlag,
		Handler: mux,
	}
	serverCh := make(chan struct{})
	go func() {
		log.Printf("[INFO] server is listening on %s\n", *listenFlag)
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("[ERR] server exited with: %s", err)
		}
		close(serverCh)
	}()

	signalCh := make(chan os.Signal, 1)
	signal.Notify(signalCh, os.Interrupt)

	// Wait for interrupt
	<-signalCh

	log.Printf("[INFO] received interrupt, shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("[ERR] failed to shutdown server: %s", err)
	}

	// If we got this far, it was an interrupt, so don't exit cleanly
	os.Exit(2)
}
