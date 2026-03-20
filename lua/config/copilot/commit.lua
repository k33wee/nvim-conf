local M = {}

local commit_message_generation_in_progress = false

local prompt = table.concat({
  'You are a conventional commit assistant.',
  'Read the staged diff below carefully and rely on its exact content.',
  '1. Determine the best conventional type (feat, fix, docs, style, refactor, perf, test, build, chore).',
  '2. Write a single subject line in the format "<type>: <summary>" that accurately reflects the actual file changes and behaviors.',
  '3. After the subject, add a blank line and describe two or three key diff highlights as "- <change>", referencing file paths or sections exactly as they appear.',
  '4. Output only the formatted commit subject and bullet list; do not invent unrelated changes.',
}, '\n')

function M.generate()
  if vim.fn.executable 'copilot' ~= 1 then
    vim.notify('copilot CLI not found in $PATH', vim.log.levels.ERROR)
    return
  end

  if commit_message_generation_in_progress then
    vim.notify('Commit message generation already in progress', vim.log.levels.WARN)
    return
  end

  commit_message_generation_in_progress = true
  vim.notify('Generating commit message with Copilot CLI...', vim.log.levels.INFO)

  vim.system({ 'git', 'diff', '--staged', '--no-color', '--no-ext-diff' }, { text = true }, function(diff_result)
    vim.schedule(function()
      if diff_result.code ~= 0 then
        commit_message_generation_in_progress = false
        vim.notify('Failed to read staged changes', vim.log.levels.ERROR)
        return
      end

      local staged_diff = vim.trim(diff_result.stdout or '')
      if staged_diff == '' then
        commit_message_generation_in_progress = false
        vim.notify('No staged changes found', vim.log.levels.WARN)
        return
      end

      local full_prompt = table.concat({ prompt, '', 'Staged diff:', staged_diff }, '\n')
      vim.system({ 'copilot', '--model', 'gpt-4.1', '-p', full_prompt, '--silent', '--allow-all' }, { text = true }, function(result)
        vim.schedule(function()
          commit_message_generation_in_progress = false
          if result.code ~= 0 then
            vim.notify('Failed to generate commit message with Copilot CLI', vim.log.levels.ERROR)
            return
          end

          local message = vim.trim(result.stdout or '')
          if message == '' then
            vim.notify('Copilot CLI returned an empty commit message', vim.log.levels.WARN)
            return
          end

          vim.fn.setreg('+', message)
          vim.fn.setreg('"', message)
          vim.notify('Commit message copied to clipboard', vim.log.levels.INFO)
        end)
      end)
    end)
  end)
end

return M
