package cmd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/NETWAYS/go-check"
)

func TestFileContent(t *testing.T) {
	dir := t.TempDir()
	filePath := filepath.Join(dir, "stat_critical.txt")
	fileContent := "+CREG: 1,1\n+CSQ: 5,99\n+COPS: 0,0,\"Telekom\""
	expected := "+CREG: 1,1\n+CSQ: 5,99\n+COPS: 0,0,\"Telekom\""

	err := os.WriteFile(filePath, []byte(fileContent), 0644)

	if err != nil {
		t.Fatalf("Did not expect error while writing file: %v", err)
	}

	content, _, _ := getFileContentAndInfo(filePath)

	actual := string(content)

	if actual != expected {
		t.Errorf("expected: %q, actual: %q", expected, actual)
	}
}

type checkContentTest struct {
	name             string
	expectedStatus   string
	expectedOutput   string
	expectedPerfData string
	fileContent      string
	warnThreshold    string
	critThreshold    string
}

func TestCheckRexeg(t *testing.T) {

	tests := []checkContentTest{
		{
			name:           "CRITICAL",
			expectedStatus: check.CriticalString,
			expectedOutput: "Registered on network 'UNITTEST' with signal strength 16%",
			fileContent:    "+CREG: 1,1\n+CSQ: 5,99\n+COPS: 0,0,\"UNITTEST\"",
			warnThreshold:  "50:",
			critThreshold:  "20:",
		},
		{
			name:           "OK",
			expectedStatus: check.OKString,
			expectedOutput: "Registered on network 'EXAMPLE' with signal strength 74%",
			fileContent:    "+CREG: 1,1\n+CSQ: 23,5|\n+COPS: 0,0,\"EXAMPLE\"",
			warnThreshold:  "50:",
			critThreshold:  "20:",
		},
		{
			name:             "WARNING with bitrate",
			expectedStatus:   check.WarningString,
			expectedOutput:   "Registered on network '02' with signal strength 45%",
			expectedPerfData: "dbm=-85 signal=45%;50:;20: bit_error_rate=3",
			fileContent:      "+CREG: 1,1\n+CSQ: 14,3|\n+COPS: 0,0,\"02\"",
			warnThreshold:    "50:",
			critThreshold:    "20:",
		},
		{
			name:           "CRITICAL with modem not registered",
			expectedStatus: check.CriticalString,
			expectedOutput: "Modem not registered on network",
			fileContent:    "+CREG: 0,0\n+CSQ: 20,2\n+COPS: 0,0,\"EXAMPLE\"",
			warnThreshold:  "50:",
			critThreshold:  "20:",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			warnThreshold, _ := check.ParseThreshold(test.warnThreshold)
			critThreshold, _ := check.ParseThreshold(test.critThreshold)

			result := checkContent(string(test.fileContent), *warnThreshold, *critThreshold)

			if !strings.Contains(result.String(), test.expectedOutput) {
				t.Errorf("expected output: %q, actual: %q ", test.expectedOutput, result.String())
			}

			if result.GetStatus().String() != test.expectedStatus {
				t.Errorf("expected status: %s, actual: %s", test.expectedStatus, result.GetStatus().String())
			}
		})
	}
}
