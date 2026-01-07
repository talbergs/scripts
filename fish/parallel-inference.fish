#!/usr/bin/env fish
# Parallel & piped inference orchestration for Ollama
# Composes multiple inference jobs intelligently

set -g INFERENCE_TMPDIR (mktemp -d)
set -g MAX_CONCURRENT_JOBS 2

# ============================================================================
# JOB QUEUE MANAGEMENT
# ============================================================================

function _enqueue_job
    set -l job_name $argv[1]
    set -l job_fn $argv[2]
    set -l args $argv[3..]
    
    set -l queue_file $INFERENCE_TMPDIR/queue
    echo "$job_name|$job_fn|$args" >> $queue_file
end

function _process_queue
    set -l queue_file $INFERENCE_TMPDIR/queue
    set -l active_jobs 0
    
    if not test -f $queue_file
        return 0
    end
    
    while read -l job_line
        while test (count (jobs -p)) -ge $MAX_CONCURRENT_JOBS
            sleep 0.1
        end
        
        set -l parts (string split '|' $job_line)
        set -l job_name $parts[1]
        set -l job_fn $parts[2]
        set -l args $parts[3..]
        
        eval "$job_fn $args" &
    end < $queue_file
    
    wait
end

# ============================================================================
# INFERENCE STRATEGIES
# ============================================================================

function _infer_single
    set -l binary $argv[1]
    set -l model $argv[2]
    set -l output_file $INFERENCE_TMPDIR/$binary.out
    
    set -l prompt "Generate fish completions for '$binary':"
    
    timeout 12 ollama run $model "$prompt" 2>/dev/null > $output_file
    echo "[$binary] ✓"
end

function _infer_batched
    # Batches multiple binaries into single inference for efficiency
    set -l binaries $argv[1..-2]
    set -l model $argv[-1]
    set -l output_file $INFERENCE_TMPDIR/batch.out
    
    set -l prompt "Generate fish completions for these commands: $(string join ', ' $binaries)"
    
    timeout 20 ollama run $model "$prompt" 2>/dev/null > $output_file
    echo "[batch] ✓"
end

function _infer_piped
    # Chains inferences: output of one feeds into next for refinement
    set -l binary $argv[1]
    set -l model $argv[2]
    
    # Stage 1: Generate initial completions
    set -l stage1 (timeout 10 ollama run $model "Basic fish completions for $binary" 2>/dev/null)
    
    # Stage 2: Refine based on stage 1
    if test -n "$stage1"
        timeout 10 ollama run $model "Refine this: $stage1" 2>/dev/null > $INFERENCE_TMPDIR/$binary.refined.out
        echo "[$binary refined] ✓"
    end
end

# ============================================================================
# SMART COMPOSITION
# ============================================================================

function infer_smart
    set -l binaries $argv[1..-2]
    set -l model $argv[-1]
    set -l batch_size 3
    set -l total (count $binaries)
    
    if test $total -le 1
        # Single binary: use piped strategy for refinement
        _infer_piped $binaries[1] $model
    else if test $total -le 5
        # Few binaries: batch them together
        _infer_batched $binaries $model
    else
        # Many binaries: parallel individual inferences
        for binary in $binaries
            _enqueue_job $binary _infer_single $binary $model
        end
        _process_queue
    end
end

# ============================================================================
# RESULT ASSEMBLY
# ============================================================================

function _assemble_result
    set -l binary $argv[1]
    set -l output_file $argv[2]
    
    # Collect outputs from various inference stages
    set -l result ""
    
    if test -f $INFERENCE_TMPDIR/$binary.out
        set result (cat $INFERENCE_TMPDIR/$binary.out)
    end
    
    if test -f $INFERENCE_TMPDIR/$binary.refined.out
        set result (cat $INFERENCE_TMPDIR/$binary.refined.out)
    end
    
    if test -z "$result"
        set result "# Failed to generate completions for $binary"
    end
    
    echo "set -l binary \"$binary\"" > $output_file
    echo "$result" >> $output_file
end

function assemble_all_results
    set -l output_dir $argv[1]
    mkdir -p $output_dir
    
    for output_file in $INFERENCE_TMPDIR/*.out
        if test ! -f $output_file
            continue
        end
        
        set -l binary (basename $output_file .out)
        _assemble_result $binary $output_dir/$binary.fish
        echo "Assembled: $binary"
    end
    
    echo "✓ All results in $output_dir"
end

# ============================================================================
# CLEANUP
# ============================================================================

function inference_cleanup
    rm -rf $INFERENCE_TMPDIR
end

trap inference_cleanup EXIT
