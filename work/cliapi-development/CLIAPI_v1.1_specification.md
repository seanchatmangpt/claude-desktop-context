# CLIAPI Specification v1.1

## Contract-First CLI Development

**Version:** 1.1.0  
**Philosophy:** Like OpenAPI, but for CLI tools. Complete contracts for code generation.

---

## Core Design Principles

1. **Contract-First** - Specification drives implementation
2. **Code Generation Ready** - Contains everything needed to generate working tools
3. **Streaming Native** - Long operations stream results (like AsyncAPI)
4. **Type Safe** - Strong JSON Schema contracts for Rust generation
5. **Token Efficient** - Concise specs, no bloat

---

## Specification Structure

```yaml
cliapi: "1.1.0"
info:
  name: file-list
  version: "1.0.0"
  description: "List files and directories"

commands:
  list:
    parameters: []
    responses: {}
    errors: []
    
streams: {}    # NEW: Streaming response definitions
schemas: {}
```

---

## Commands Object

The core of CLIAPI - defines what the tool does:

```yaml
commands:
  list:
    summary: "List files in directory"
    
    parameters:
      - name: path
        type: argument          # argument | flag | option
        required: true
        schema:
          type: string
          format: path
      
      - name: recursive  
        type: flag
        schema:
          type: boolean
          default: false
          
      - name: format
        type: option
        schema:
          type: string
          enum: ["json", "ndjson"]
          default: "ndjson"
    
    responses:
      success:
        description: "File listing completed"
        schema:
          $ref: "#/schemas/FileList"
          
    streams:
      progress:
        description: "Files as they're discovered"
        message:
          $ref: "#/schemas/FileInfo"
          
    errors:
      - exit_code: 2
        name: not_found
        message: "Directory not found: {path}"
      - exit_code: 77  
        name: permission_denied
        message: "Permission denied: {path}"
```

---

## NEW: Streams Object

Define streaming responses for long-running operations:

```yaml
streams:
  file_discovery:
    description: "Files discovered during recursive scan"
    content_type: "application/x-ndjson"
    message:
      $ref: "#/schemas/FileInfo"
    completion:
      $ref: "#/schemas/ScanComplete"
      
  progress_updates:
    description: "Progress information"  
    content_type: "application/x-ndjson"
    message:
      type: object
      properties:
        current:
          type: integer
        total:
          type: integer
        message:
          type: string
      required: [current, total]
```

---

## Enhanced Error Definitions

Standard Unix exit codes with structured messages:

```yaml
errors:
  - exit_code: 2
    name: invalid_path
    message: "Invalid path: {path}"
    category: user_error
    
  - exit_code: 77
    name: permission_denied  
    message: "Permission denied: {path}"
    category: user_error
    
  - exit_code: 1
    name: io_error
    message: "I/O error: {details}"
    category: system_error
    recoverable: true
```

---

## Parameter Types

Three fundamental CLI parameter patterns:

```yaml
parameters:
  # Positional argument
  - name: input_file
    type: argument
    position: 0              # Order for positional args
    required: true
    schema:
      type: string
      format: file-path
      
  # Boolean flag  
  - name: verbose
    type: flag
    aliases: ["v"]           # Short forms
    schema:
      type: boolean
      default: false
      
  # Key-value option
  - name: output_format
    type: option
    aliases: ["f", "format"] 
    schema:
      type: string
      enum: ["json", "csv", "table"]
      default: "json"
```

---

## Complete Example

```yaml
cliapi: "1.1.0"
info:
  name: file-scanner
  version: "2.0.0"  
  description: "Fast file system scanner"
  author: "dev@example.com"

commands:
  scan:
    summary: "Scan directory for files"
    
    parameters:
      - name: directory
        type: argument
        position: 0
        required: true
        schema:
          type: string
          format: directory-path
          
      - name: recursive
        type: flag
        aliases: ["r"]
        schema:
          type: boolean
          default: false
          
      - name: pattern
        type: option
        aliases: ["p"]
        schema:
          type: string
          format: regex
          
      - name: format
        type: option
        aliases: ["f"]
        schema:
          type: string
          enum: ["ndjson", "json", "csv"]
          default: "ndjson"
    
    responses:
      success:
        description: "Scan completed successfully"
        schema:
          type: object
          properties:
            files:
              type: array
              items:
                $ref: "#/schemas/FileEntry"
            stats:
              $ref: "#/schemas/ScanStats"
          required: [files, stats]
    
    streams:
      file_stream:
        description: "Files discovered during scan"
        message:
          $ref: "#/schemas/FileEntry"
        completion:
          $ref: "#/schemas/ScanStats"
          
    errors:
      - exit_code: 2
        name: directory_not_found
        message: "Directory not found: {directory}"
        category: user_error
        
      - exit_code: 77
        name: permission_denied
        message: "Permission denied: {directory}"  
        category: user_error
        
      - exit_code: 1
        name: scan_failed
        message: "Scan failed: {error}"
        category: system_error
        recoverable: true

schemas:
  FileEntry:
    type: object
    properties:
      path:
        type: string
        format: file-path
      name:
        type: string
      size:
        type: integer
        minimum: 0
      is_directory:
        type: boolean
      modified:
        type: integer
        format: unix-timestamp
    required: [path, name, size, is_directory, modified]
    
  ScanStats:
    type: object
    properties:
      total_files:
        type: integer
      total_directories:
        type: integer
      total_size:
        type: integer
      duration_ms:
        type: integer
    required: [total_files, total_directories, total_size, duration_ms]
```

---

## Code Generation Mapping

How CLIAPI maps to Rust code:

```yaml
# CLIAPI parameter
- name: max_depth
  type: option
  schema:
    type: integer
    minimum: 1
    maximum: 100
    default: 10

# Generated Rust
#[derive(Parser)]
struct Args {
    #[arg(long, default_value = "10")]
    #[arg(value_parser = clap::value_parser!(u32).range(1..=100))]
    max_depth: u32,
}
```

```yaml
# CLIAPI stream
streams:
  progress:
    message:
      type: object
      properties:
        current: {type: integer}
        total: {type: integer}

# Generated Rust  
#[derive(Serialize)]
struct ProgressMessage {
    current: u64,
    total: u64,
}

fn emit_progress(current: u64, total: u64) {
    let msg = ProgressMessage { current, total };
    println!("{}", serde_json::to_string(&msg).unwrap());
}
```

---

## Implementation Requirements

For Rust code generation, CLIAPI specs must define:

1. **Complete parameter parsing** - All argument types and validation
2. **Response schemas** - Exact output structure  
3. **Error mapping** - Exit codes to error types
4. **Streaming patterns** - When and how to emit progress
5. **JSON serialization** - Type-safe serde derives

---

## Validation Rules

1. **Parameter names** must be valid Rust identifiers
2. **Schemas** must be valid JSON Schema Draft 7
3. **Exit codes** must be 0-255 (Unix standard)
4. **Stream messages** must have defined schemas
5. **Required fields** cannot have default values

---

## Conclusion

CLIAPI v1.1 focuses on the essential contract elements needed for complete code generation:

✅ **Parameter definitions** (like OpenAPI parameters)  
✅ **Response schemas** (like OpenAPI responses)  
✅ **Streaming support** (like AsyncAPI messages)  
✅ **Error contracts** (exit codes + structured messages)  
✅ **Type safety** (JSON Schema for Rust generation)

**Result:** Write a CLIAPI spec, generate a complete, type-safe Rust CLI tool with streaming support and proper error handling.

**Token efficient, code generation ready, contract-first.**
