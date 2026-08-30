package log

import (
	advlog "github.com/AvengeMedia/dankgo/log"
)

type Logger = advlog.Logger

func init() {
	advlog.SetEnvPrefix("ADVS")
}

func GetLogger() *Logger { return advlog.GetLogger() }

func GetQtLoggingRules() string { return advlog.GetQtLoggingRules() }

func SetLevel(level string) { advlog.SetLevel(level) }

func SetLogFile(path string) error { return advlog.SetLogFile(path) }

func ApplyEnvOverrides() { advlog.ApplyEnvOverrides() }

func Debug(msg any, keyvals ...any)  { advlog.Debug(msg, keyvals...) }
func Debugf(format string, v ...any) { advlog.Debugf(format, v...) }
func Info(msg any, keyvals ...any)   { advlog.Info(msg, keyvals...) }
func Infof(format string, v ...any)  { advlog.Infof(format, v...) }
func Warn(msg any, keyvals ...any)   { advlog.Warn(msg, keyvals...) }
func Warnf(format string, v ...any)  { advlog.Warnf(format, v...) }
func Error(msg any, keyvals ...any)  { advlog.Error(msg, keyvals...) }
func Errorf(format string, v ...any) { advlog.Errorf(format, v...) }
func Fatal(msg any, keyvals ...any)  { advlog.Fatal(msg, keyvals...) }
func Fatalf(format string, v ...any) { advlog.Fatalf(format, v...) }
