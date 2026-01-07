#!/usr/bin/env fish
# Fish completion generator using local Ollama 7B
# Two-phase system: Phase 1 (stub), Phase 2 (inference)

set -g COMPLETIONS_CACHE ~/.local/share/fish/generated_completions
set -g OLLAMA_MODEL llama2  # Change to your 7b model
set -g SPINNER_CHARS "⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏"

# ============================================================================
# UTILITIES
# ============================================================================

function _spinner_start
    set -l char_idx 0
    while test -n (jobs -p)
        set -l char (echo $SPINNER_CHARS | string split ' ' | head -n (math "$char_idx % 10 + 1") | tail -n 1)
        printf "\r$char  Generating completions..."
        set char_idx (math "$char_idx + 1")
        sleep 0.1
    end
    printf "\r✓ Done\n"
end

function _binaries_without_completions
    set -l completions_dir ~/.local/share/fish/vendor_completions.d
    set -l user_completions_dir ~/.config/fish/completions
    
    for bin in (string split ':' $PATH)
        if not test -d $bin
            continue
        end
        
        for executable in $bin/*
            if not test -x $executable
                continue
            end
            
            set -l name (basename $executable)
            set -l has_completion false
            
            # Check for existing completions
            if test -f "$completions_dir/$name.fish" -o -f "$user_completions_dir/$name.fish"
                set has_completion true
            end
            
            if test $has_completion = false
                echo $name
            end
        end
    end | sort -u
end

# ============================================================================
# PHASE 1: STUB-OUT
# ============================================================================

function _generate_stub_completion
    set -l binary $argv[1]
    set -l output_file $COMPLETIONS_CACHE/$binary.fish
    
    mkdir -p $COMPLETIONS_CACHE
    
    # Generate minimal stub with placeholder structure
    cat > $output_file << 'EOF'
# Auto-generated stub completion for BINARY
# Run 'fish_generate_completions BINARY' to generate intelligent completions

set -l binary "BINARY"

# Common patterns (to be replaced by phase 2)
complete -c $binary -f -d "BINARY command"
complete -c $binary -n "__fish_seen_subcommand_from --help" -d "Show help"
EOF
    
    # Replace BINARY placeholder
    sed -i '' "s/BINARY/$binary/g" $output_file
end

function phase1_stub_completions
    set -l binaries (_binaries_without_completions)
    set -l total (count $binaries)
    
    if test $total -eq 0
        echo "✓ All binaries have completions"
        return 0
    end
    
    echo "Phase 1: Creating stubs for $total binaries..."
    
    # Process in parallel with job throttling
    set -l job_limit 4
    set -l job_count 0
    
    for binary in $binaries
        _generate_stub_completion $binary &
        
        set job_count (math "$job_count + 1")
        if test $job_count -ge $job_limit
            wait
            set job_count 0
        end
    end
    wait
    
    echo "✓ Stubs created in $COMPLETIONS_CACHE"
end

# ============================================================================
# PHASE 2: INFERENCE (with Ollama)
# ============================================================================

function _ollama_prompt
    set -l binary $argv[1]
    cat << EOF
Generate fish shell completions for the '$binary' command. 
Return ONLY valid fish complete syntax. Include:
1. Basic subcommands if applicable
2. Common flags (--help, --version, etc)
3. Short descriptions

Format: complete -c $binary -f -d "description"
Format: complete -c $binary -n "condition" -a "arg" -d "description"
EOF
end

function _call_ollama
    set -l binary $argv[1]
    set -l prompt (_ollama_prompt $binary)
    
    # Call ollama with timeout fallback
    timeout 15 ollama run $OLLAMA_MODEL "$prompt" 2>/dev/null | \
        string match -r 'complete -c' | \
        head -n 20
end

function _build_completion_from_inference
    set -l binary $argv[1]
    set -l output_file $COMPLETIONS_CACHE/$binary.fish
    set -l ollama_output (_call_ollama $binary)
    
    if test -z "$ollama_output"
        echo "# Inference timeout/failed for $binary" >> $output_file
        return 1
    end
    
    # Replace stub with actual completions
    cat > $output_file << EOF
# Auto-generated completion for $binary via Ollama inference

set -l binary "$binary"

$ollama_output
EOF
    
    return 0
end

function phase2_inference_completions
    set -l stubs (ls $COMPLETIONS_CACHE/*.fish 2>/dev/null)
    
    if test -z "$stubs"
        echo "No stubs found. Run 'phase1_stub_completions' first."
        return 1
    end
    
    echo "Phase 2: Running inference on stubs (this may take a while)..."
    
    # Process with parallel inference jobs
    set -l job_limit 2
    set -l job_count 0
    
    for stub_file in $stubs
        set -l binary (basename $stub_file .fish)
        _build_completion_from_inference $binary &
        
        set job_count (math "$job_count + 1")
        if test $job_count -ge $job_limit
            wait
            set job_count 0
        end
    end
    wait
    
    echo "✓ Inference complete"
    echo "✓ Completions ready at $COMPLETIONS_CACHE"
end

# ============================================================================
# INSTALLATION & ACTIVATION
# ============================================================================

function install_generated_completions
    mkdir -p ~/.config/fish/completions
    cp $COMPLETIONS_CACHE/*.fish ~/.config/fish/completions/ 2>/dev/null
    echo "✓ Completions installed to ~/.config/fish/completions"
    echo "Restart fish or run: source ~/.config/fish/config.fish"
end

function cleanup_generated_completions
    rm -rf $COMPLETIONS_CACHE
    rm -f ~/.config/fish/completions/*_generated_*.fish
    echo "✓ Cleaned up generated completions"
end

# ============================================================================
# MAIN ORCHESTRATOR
# ============================================================================

function fish_generate_completions
    set -l phase $argv[1]
    
    switch $phase
        case phase1
            phase1_stub_completions
        case phase2
            phase2_inference_completions
        case install
            install_generated_completions
        case clean
            cleanup_generated_completions
        case all
            phase1_stub_completions
            sleep 1
            phase2_inference_completions
            install_generated_completions
        case ""
            echo "Fish Completion Generator - Two Phase System"
            echo ""
            echo "Usage: fish_generate_completions <phase>"
            echo ""
            echo "Phases:"
            echo "  phase1   - Create stub completions (fast)"
            echo "  phase2   - Run Ollama inference on stubs (slower)"
            echo "  install  - Install generated completions"
            echo "  clean    - Remove all generated completions"
            echo "  all      - Run phase1 → phase2 → install"
            echo ""
            echo "Example workflow:"
            echo "  fish_generate_completions phase1"
            echo "  fish_generate_completions phase2"
            echo "  fish_generate_completions install"
    end
end
