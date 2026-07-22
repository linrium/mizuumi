package main

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/transparency-dev/tessera"
	"github.com/transparency-dev/tessera/storage/posix"
	"github.com/yokeTH/gofiber-scalar/scalar/v3"
	"golang.org/x/mod/sumdb/note"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg := loadConfig()
	if err := os.MkdirAll(cfg.logDir, 0o755); err != nil {
		log.Fatalf("create log dir: %v", err)
	}
	if err := os.MkdirAll(filepath.Dir(cfg.signerKeyFile), 0o755); err != nil {
		log.Fatalf("create signer key dir: %v", err)
	}

	signer, verifierKey, err := loadOrCreateSigner(cfg.signerKeyFile)
	if err != nil {
		log.Fatalf("load signer: %v", err)
	}

	driver, err := posix.New(ctx, posix.Config{Path: cfg.logDir})
	if err != nil {
		log.Fatalf("create Tessera POSIX driver: %v", err)
	}

	appender, shutdown, reader, err := tessera.NewAppender(ctx, driver, tessera.NewAppendOptions().
		WithCheckpointSigner(signer).
		WithCheckpointInterval(time.Second).
		WithCheckpointRepublishInterval(time.Minute).
		WithBatching(256, time.Second))
	if err != nil {
		log.Fatalf("create Tessera appender: %v", err)
	}
	defer func() {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := shutdown(shutdownCtx); err != nil {
			log.Printf("shutdown Tessera appender: %v", err)
		}
	}()

	app := fiber.New()

	app.Get("/docs/*", scalar.New(scalar.Config{
		FileContentString: openAPISpec,
		Path:              "/docs",
		Title:             "Mizukagami API",
		Theme:             scalar.ThemeDefault,
	}))

	app.Get("/", func(c fiber.Ctx) error {
		return c.SendString("mizukagami")
	})

	app.Get("/healthz", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"ok": true})
	})

	app.Get("/tessera", func(c fiber.Ctx) error {
		nextIndex, err := reader.NextIndex(c.Context())
		if err != nil {
			return fiber.NewError(fiber.StatusInternalServerError, err.Error())
		}
		integratedSize, err := reader.IntegratedSize(c.Context())
		if err != nil {
			return fiber.NewError(fiber.StatusInternalServerError, err.Error())
		}

		return c.JSON(fiber.Map{
			"log_dir":         cfg.logDir,
			"signer":          signer.Name(),
			"verifier_key":    verifierKey,
			"next_index":      nextIndex,
			"integrated_size": integratedSize,
		})
	})

	app.Post("/entries", func(c fiber.Ctx) error {
		body := c.Body()
		if len(body) == 0 {
			return fiber.NewError(fiber.StatusBadRequest, "entry body is required")
		}

		index, err := appender.Add(c.Context(), tessera.NewEntry(body))()
		if err != nil {
			return fiber.NewError(fiber.StatusInternalServerError, err.Error())
		}

		return c.Status(fiber.StatusCreated).JSON(fiber.Map{
			"index":        index.Index,
			"duplicate":    index.IsDup,
			"published_by": "/checkpoint",
		})
	})

	app.Get("/checkpoint", func(c fiber.Ctx) error {
		checkpoint, err := reader.ReadCheckpoint(c.Context())
		if err != nil {
			status := fiber.StatusInternalServerError
			if errors.Is(err, os.ErrNotExist) {
				status = fiber.StatusNotFound
			}
			return fiber.NewError(status, err.Error())
		}
		c.Type("text")
		return c.Send(checkpoint)
	})

	app.Get("/tile/*", func(c fiber.Ctx) error {
		return sendLogFile(c, cfg.logDir, "tile", c.Params("*"))
	})
	app.Get("/entries/*", func(c fiber.Ctx) error {
		return sendLogFile(c, cfg.logDir, filepath.Join("tile", "entries"), c.Params("*"))
	})

	go func() {
		<-ctx.Done()
		if err := app.Shutdown(); err != nil {
			log.Printf("shutdown Fiber app: %v", err)
		}
	}()

	if err := app.Listen(cfg.listenAddr); err != nil {
		log.Fatal(err)
	}
}

type config struct {
	listenAddr    string
	logDir        string
	signerKeyFile string
}

func loadConfig() config {
	logDir := getenv("MIZUKAGAMI_LOG_DIR", ".data/tessera")
	return config{
		listenAddr:    getenv("MIZUKAGAMI_ADDR", ":3000"),
		logDir:        logDir,
		signerKeyFile: getenv("MIZUKAGAMI_SIGNER_KEY_FILE", filepath.Join(logDir, ".state", "signer.key")),
	}
}

func loadOrCreateSigner(path string) (note.Signer, string, error) {
	signerKey, err := os.ReadFile(path)
	if err == nil {
		signer, err := note.NewSigner(string(signerKey))
		if err != nil {
			return nil, "", err
		}

		verifierKey, err := os.ReadFile(path + ".pub")
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return nil, "", fmt.Errorf("read verifier key: %w", err)
		}
		return signer, string(verifierKey), nil
	}
	if !errors.Is(err, os.ErrNotExist) {
		return nil, "", fmt.Errorf("read signer key: %w", err)
	}

	signerKeyString, verifierKey, err := note.GenerateKey(rand.Reader, "mizukagami")
	if err != nil {
		return nil, "", fmt.Errorf("generate signer key: %w", err)
	}
	if err := os.WriteFile(path, []byte(signerKeyString), 0o600); err != nil {
		return nil, "", fmt.Errorf("write signer key: %w", err)
	}
	if err := os.WriteFile(path+".pub", []byte(verifierKey), 0o644); err != nil {
		return nil, "", fmt.Errorf("write verifier key: %w", err)
	}

	signer, err := note.NewSigner(signerKeyString)
	return signer, verifierKey, err
}

func sendLogFile(c fiber.Ctx, root, prefix, requested string) error {
	cleaned := filepath.Clean(filepath.Join(prefix, requested))
	if cleaned == "." || cleaned == prefix || !strings.HasPrefix(cleaned, prefix+string(filepath.Separator)) {
		return fiber.NewError(fiber.StatusBadRequest, "invalid log path")
	}

	path := filepath.Join(root, cleaned)
	if _, err := os.Stat(path); err != nil {
		status := fiber.StatusInternalServerError
		if errors.Is(err, os.ErrNotExist) {
			status = fiber.StatusNotFound
		}
		return fiber.NewError(status, err.Error())
	}
	return c.SendFile(path)
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
