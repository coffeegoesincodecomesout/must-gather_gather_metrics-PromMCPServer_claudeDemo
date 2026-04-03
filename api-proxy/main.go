package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
)

func main() {
	modelAPI := requireEnv("MODEL_API")
	modelID := requireEnv("MODEL_ID")
	userKey := requireEnv("USER_KEY")
	port := os.Getenv("PROXY_PORT")
	if port == "" {
		port = "8787"
	}

	targetURL := fmt.Sprintf("%s/sonnet/models/%s:streamRawPredict", modelAPI, modelID)

	http.HandleFunc("/v1/messages", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		// Transform Anthropic format → Vertex format
		delete(body, "model") // model is encoded in the target URL
		body["anthropic_version"] = "vertex-2023-10-16"

		payload, err := json.Marshal(body)
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}

		req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, targetURL, bytes.NewReader(payload))
		if err != nil {
			http.Error(w, "internal error", http.StatusInternalServerError)
			return
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+userKey)

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()

		// Forward response headers and status
		for k, vals := range resp.Header {
			for _, v := range vals {
				w.Header().Add(k, v)
			}
		}
		w.WriteHeader(resp.StatusCode)

		// Stream response body back to Claude Code
		if f, ok := w.(http.Flusher); ok {
			buf := make([]byte, 4096)
			for {
				n, readErr := resp.Body.Read(buf)
				if n > 0 {
					w.Write(buf[:n])
					f.Flush()
				}
				if readErr == io.EOF {
					break
				}
				if readErr != nil {
					log.Printf("stream error: %v", readErr)
					break
				}
			}
		} else {
			io.Copy(w, resp.Body)
		}
	})

	addr := "127.0.0.1:" + port
	log.Printf("api-proxy: listening on http://%s -> %s", addr, targetURL)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatal(err)
	}
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("ERROR: %s must be set", key)
	}
	return v
}
