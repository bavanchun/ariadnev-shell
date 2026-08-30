;;; adv-emacs-theme.el --- Enhanced theme using Matugen SCSS variables with adv16 colors -*- lexical-binding: t; -*-

;; Copyright (C) 2025

;; Author: Generated (Enhanced)
;; Version: 1.3
;; Package-Requires: ((emacs "24.1"))
;; Keywords: faces

;;; Commentary:

;; An enhanced theme using Matugen SCSS variables integrated with adv16 colors:
;; - Rich color palette from adv16 for vibrant syntax highlighting
;; - Improved contrast and readability
;; - Better source block distinction with refined backgrounds
;; - Enhanced org-mode styling with hidden asterisks
;; - Superior visual hierarchy and modern aesthetics

;;; Code:

(deftheme adv-emacs "Enhanced theme using Matugen variables with adv16 color integration.")

;; Define all the color variables (replaced by template processor)
(let* ((bg "{{colors.background.default.hex}}")
      (err "{{adv16.color1.default.hex}}")  ; Red from adv16
      (err-container "{{colors.error_container.default.hex}}")
      (on-background "{{colors.on_background.default.hex}}")
      (on-err "{{colors.on_error.default.hex}}")
      (on-err-container "{{colors.on_error_container.default.hex}}")
      (on-primary "{{colors.on_primary.default.hex}}")
      (on-primary-container "{{colors.on_primary_container.default.hex}}")
      (on-secondary "{{colors.on_secondary.default.hex}}")
      (on-secondary-container "{{colors.on_secondary_container.default.hex}}")
      (on-surface "{{colors.on_surface.default.hex}}")
      (on-surface-variant "{{colors.on_surface_variant.default.hex}}")
      (on-tertiary "{{colors.on_tertiary.default.hex}}")
      (on-tertiary-container "{{colors.on_tertiary_container.default.hex}}")
      (outline-color "{{colors.outline.default.hex}}")
      (outline-variant "{{colors.outline_variant.default.hex}}")
      (primary "{{colors.primary.default.hex}}")
      (primary-container "{{colors.primary_container.default.hex}}")
      (secondary "{{colors.secondary.default.hex}}")
      (secondary-container "{{colors.secondary_container.default.hex}}")
      (shadow "{{colors.shadow.default.hex}}")
      (surface "{{colors.surface.default.hex}}")
      (surface-container "{{colors.surface_container_high.default.hex}}")
      (surface-container-high "{{colors.surface_container_highest.default.hex}}")
      (surface-container-highest "{{colors.surface_container_high.default.hex}}")
      (surface-container-low "{{colors.surface_container_low.default.hex}}")
      (surface-container-lowest "{{colors.surface_container_lowest.default.hex}}")
      (surface-variant "{{colors.surface_variant.default.hex}}")
      (tertiary "{{colors.tertiary.default.hex}}")
      (tertiary-container "{{colors.tertiary_container.default.hex}}")

      ;; Enhanced adv16 colors for better syntax highlighting
      (adv-red "{{adv16.color1.default.hex}}")          ; Bright red
      (adv-red-alt "{{adv16.color9.default.hex}}")      ; Alternative red
      (adv-green "{{adv16.color2.default.hex}}")        ; Vibrant green
      (adv-green-bright "{{adv16.color10.default.hex}}") ; Bright green
      (adv-yellow "{{adv16.color3.default.hex}}")       ; Warm yellow
      (adv-yellow-bright "{{adv16.color11.default.hex}}") ; Bright yellow
      (adv-blue "{{adv16.color4.default.hex}}")         ; Blue-green
      (adv-magenta "{{adv16.color5.default.hex}}")      ; Teal-magenta
      (adv-cyan "{{adv16.color6.default.hex}}")         ; Bright cyan
      (adv-cyan-bright "{{adv16.color12.default.hex}}") ; Brightest cyan
      (adv-cyan-dark "{{adv16.color13.default.hex}}")   ; Dark cyan
      (adv-teal "{{adv16.color14.default.hex}}")        ; Dark teal
      (adv-fg "{{adv16.color7.default.hex}}")           ; Light foreground
      (adv-gray "{{adv16.color8.default.hex}}")         ; Gray
      (adv-white "{{adv16.color15.default.hex}}")       ; White

      ;; Map success colors to green
      (success "{{adv16.color2.default.hex}}")
      (on-success "{{colors.on_tertiary.default.hex}}")
      (success-container "{{colors.tertiary_container.default.hex}}")
      (on-success-container "{{colors.on_tertiary_container.default.hex}}")

      ;; Map fixed colors
      (primary-fixed "{{colors.primary_fixed.default.hex}}")
      (primary-fixed-dim "{{colors.primary_fixed_dim.default.hex}}")
      (secondary-fixed "{{colors.secondary_fixed.default.hex}}")
      (secondary-fixed-dim "{{colors.secondary_fixed_dim.default.hex}}")
      (tertiary-fixed "{{colors.tertiary_fixed.default.hex}}")
      (tertiary-fixed-dim "{{colors.tertiary_fixed_dim.default.hex}}")
      (on-primary-fixed "{{colors.on_primary_fixed.default.hex}}")
      (on-primary-fixed-variant "{{colors.on_primary_fixed_variant.default.hex}}")
      (on-secondary-fixed "{{colors.on_secondary_fixed.default.hex}}")
      (on-secondary-fixed-variant "{{colors.on_secondary_fixed_variant.default.hex}}")
      (on-tertiary-fixed "{{colors.on_tertiary_fixed.default.hex}}")
      (on-tertiary-fixed-variant "{{colors.on_tertiary_fixed_variant.default.hex}}")

      ;; Map inverse colors
      (inverse-on-surface "{{colors.inverse_on_surface.default.hex}}")
      (inverse-primary "{{colors.inverse_primary.default.hex}}")
      (inverse-surface "{{colors.inverse_surface.default.hex}}")

      ;; Terminal colors from adv16
      (term0 "{{adv16.color0.default.hex}}")
      (term1 "{{adv16.color1.default.hex}}")
      (term2 "{{adv16.color2.default.hex}}")
      (term3 "{{adv16.color3.default.hex}}")
      (term4 "{{adv16.color4.default.hex}}")
      (term5 "{{adv16.color5.default.hex}}")
      (term6 "{{adv16.color6.default.hex}}")
      (term7 "{{adv16.color7.default.hex}}")
      (term8 "{{adv16.color8.default.hex}}")
      (term9 "{{adv16.color9.default.hex}}")
      (term10 "{{adv16.color10.default.hex}}")
      (term11 "{{adv16.color11.default.hex}}")
      (term12 "{{adv16.color12.default.hex}}")
      (term13 "{{adv16.color13.default.hex}}")
      (term14 "{{adv16.color14.default.hex}}")
      (term15 "{{adv16.color15.default.hex}}"))

  (custom-theme-set-faces
   'adv-emacs
   ;; Basic faces
   `(default ((t (:background ,bg :foreground ,on-background))))
   `(cursor ((t (:background ,adv-cyan-bright))))
   `(highlight ((t (:background ,primary-container :foreground ,on-primary-container))))
   `(region ((t (:background ,primary-container :foreground ,adv-cyan-bright :extend t))))
   `(secondary-selection ((t (:background ,secondary-container :foreground ,on-secondary-container :extend t))))
   `(isearch ((t (:background ,adv-yellow :foreground ,bg :weight bold))))
   `(lazy-highlight ((t (:background ,secondary-container :foreground ,adv-yellow-bright))))
   `(vertical-border ((t (:foreground ,surface-variant))))
   `(border ((t (:background ,surface-variant :foreground ,surface-variant))))
   `(fringe ((t (:background ,surface :foreground ,adv-gray))))
   `(shadow ((t (:foreground ,adv-gray))))
   `(link ((t (:foreground ,adv-cyan-bright :underline t))))
   `(link-visited ((t (:foreground ,adv-magenta :underline t))))
   `(success ((t (:foreground ,success))))
   `(warning ((t (:foreground ,adv-yellow))))
   `(error ((t (:foreground ,err))))
   `(match ((t (:background ,adv-yellow :foreground ,bg :weight bold))))

   ;; Font-lock - enhanced with adv16 colors for vibrant syntax highlighting
   `(font-lock-builtin-face ((t (:foreground ,adv-cyan-bright))))
   `(font-lock-comment-face ((t (:foreground ,adv-gray :slant italic))))
   `(font-lock-comment-delimiter-face ((t (:foreground ,outline-variant))))
   `(font-lock-constant-face ((t (:foreground ,adv-yellow-bright :weight bold))))
   `(font-lock-doc-face ((t (:foreground ,adv-fg :slant italic))))
   `(font-lock-function-name-face ((t (:foreground ,adv-cyan :weight bold))))
   `(font-lock-keyword-face ((t (:foreground ,adv-red-alt :weight bold))))
   `(font-lock-string-face ((t (:foreground ,adv-green))))
   `(font-lock-type-face ((t (:foreground ,adv-yellow))))
   `(font-lock-variable-name-face ((t (:foreground ,adv-fg))))
   `(font-lock-warning-face ((t (:foreground ,err :weight bold))))
   `(font-lock-preprocessor-face ((t (:foreground ,adv-teal))))
   `(font-lock-negation-char-face ((t (:foreground ,adv-red))))

   ;; Show paren
   `(show-paren-match ((t (:background ,primary-container :foreground ,adv-cyan-bright :weight bold))))
   `(show-paren-mismatch ((t (:background ,err-container :foreground ,on-err-container :weight bold))))

   ;; Mode line - improved status bar styling
   `(mode-line ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(mode-line-inactive ((t (:background ,surface :foreground ,adv-gray :box nil))))
   `(mode-line-buffer-id ((t (:foreground ,adv-cyan :weight bold))))
   `(mode-line-emphasis ((t (:foreground ,adv-cyan :weight bold))))
   `(mode-line-highlight ((t (:foreground ,adv-cyan-bright :box nil))))

   ;; Improved Source blocks - seamless integration
   `(org-block ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(org-block-begin-line ((t (:background ,surface-container-low :foreground ,adv-teal :extend t :slant italic :inherit fixed-pitch))))
   `(org-block-end-line ((t (:background ,surface-container-low :foreground ,adv-teal :extend t :slant italic :inherit fixed-pitch))))
   `(org-code ((t (:background ,surface-container-low :foreground ,adv-yellow-bright :inherit fixed-pitch))))
   `(org-verbatim ((t (:background ,surface-container-low :foreground ,adv-cyan :inherit fixed-pitch))))
   `(org-meta-line ((t (:foreground ,adv-gray :slant italic))))

   ;; Org mode with enhanced colors and hidden asterisks
   `(org-level-1 ((t (:foreground ,adv-cyan :weight bold :height 1.2))))
   `(org-level-2 ((t (:foreground ,adv-blue :weight bold :height 1.1))))
   `(org-level-3 ((t (:foreground ,adv-magenta :weight bold))))
   `(org-level-4 ((t (:foreground ,adv-green :weight bold))))
   `(org-level-5 ((t (:foreground ,adv-yellow :weight bold))))
   `(org-level-6 ((t (:foreground ,adv-cyan-bright :weight bold))))
   `(org-level-7 ((t (:foreground ,adv-red-alt :weight bold))))
   `(org-level-8 ((t (:foreground ,adv-teal :weight bold))))
   `(org-document-title ((t (:foreground ,adv-cyan :weight bold :height 1.3))))
   `(org-document-info ((t (:foreground ,adv-blue))))
   `(org-todo ((t (:foreground ,adv-red :weight bold))))
   `(org-done ((t (:foreground ,success :weight bold))))
   `(org-headline-done ((t (:foreground ,adv-gray))))
   `(org-hide ((t (:foreground ,bg))))
   `(org-ellipsis ((t (:foreground ,adv-blue :underline nil))))
   `(org-table ((t (:foreground ,adv-magenta :inherit fixed-pitch))))
   `(org-formula ((t (:foreground ,adv-yellow-bright :inherit fixed-pitch))))
   `(org-checkbox ((t (:foreground ,adv-cyan :weight bold :inherit fixed-pitch))))
   `(org-date ((t (:foreground ,adv-teal :underline t))))
   `(org-special-keyword ((t (:foreground ,adv-gray :slant italic))))
   `(org-tag ((t (:foreground ,adv-gray :weight normal))))

   ;; Magit with enhanced diff colors
   `(magit-section-highlight ((t (:background ,surface-container-low))))
   `(magit-diff-hunk-heading ((t (:background ,surface-container :foreground ,adv-gray))))
   `(magit-diff-hunk-heading-highlight ((t (:background ,surface-container-high :foreground ,on-surface))))
   `(magit-diff-context ((t (:foreground ,adv-gray))))
   `(magit-diff-context-highlight ((t (:background ,surface-container-low :foreground ,on-surface))))
   `(magit-diff-added ((t (:background ,success-container :foreground ,adv-green-bright))))
   `(magit-diff-added-highlight ((t (:background ,success-container :foreground ,adv-green-bright :weight bold))))
   `(magit-diff-removed ((t (:background ,err-container :foreground ,adv-red-alt))))
   `(magit-diff-removed-highlight ((t (:background ,err-container :foreground ,adv-red-alt :weight bold))))
   `(magit-hash ((t (:foreground ,adv-gray))))
   `(magit-branch-local ((t (:foreground ,adv-blue :weight bold))))
   `(magit-branch-remote ((t (:foreground ,adv-cyan :weight bold))))

   ;; Company
   `(company-tooltip ((t (:background ,surface-container :foreground ,on-surface))))
   `(company-tooltip-selection ((t (:background ,primary-container :foreground ,adv-cyan-bright))))
   `(company-tooltip-common ((t (:foreground ,adv-cyan))))
   `(company-tooltip-common-selection ((t (:foreground ,adv-cyan-bright :weight bold))))
   `(company-tooltip-annotation ((t (:foreground ,adv-yellow))))
   `(company-scrollbar-fg ((t (:background ,adv-cyan))))
   `(company-scrollbar-bg ((t (:background ,surface-variant))))
   `(company-preview ((t (:foreground ,adv-gray :slant italic))))
   `(company-preview-common ((t (:foreground ,adv-cyan :slant italic))))

   ;; Ido
   `(ido-first-match ((t (:foreground ,adv-cyan :weight bold))))
   `(ido-only-match ((t (:foreground ,adv-green :weight bold))))
   `(ido-subdir ((t (:foreground ,adv-blue))))
   `(ido-indicator ((t (:foreground ,adv-red))))
   `(ido-virtual ((t (:foreground ,adv-gray))))

   ;; Helm
   `(helm-selection ((t (:background ,primary-container :foreground ,adv-cyan-bright))))
   `(helm-match ((t (:foreground ,adv-cyan :weight bold))))
   `(helm-source-header ((t (:background ,surface-container-high :foreground ,adv-cyan :weight bold :height 1.1))))
   `(helm-candidate-number ((t (:foreground ,adv-yellow :weight bold))))
   `(helm-ff-directory ((t (:foreground ,adv-cyan :weight bold))))
   `(helm-ff-file ((t (:foreground ,on-surface))))
   `(helm-ff-executable ((t (:foreground ,adv-green))))

   ;; corfu
   `(corfu-default ((t (:background ,surface-container :foreground ,on-surface))))
   `(corfu-current ((t (:background ,primary-container :foreground ,adv-cyan-bright))))

   ;; Which-key
   `(which-key-key-face ((t (:foreground ,adv-cyan :weight bold))))
   `(which-key-separator-face ((t (:foreground ,outline-variant))))
   `(which-key-command-description-face ((t (:foreground ,on-surface))))
   `(which-key-group-description-face ((t (:foreground ,adv-blue))))
   `(which-key-special-key-face ((t (:foreground ,adv-yellow :weight bold))))

   ;; Line numbers
   `(line-number ((t (:foreground ,adv-gray :inherit default))))
   `(line-number-current-line ((t (:foreground ,adv-cyan :weight bold :inherit default))))

   ;; Parenthesis matching
   `(sp-show-pair-match-face ((t (:background ,primary-container :foreground ,adv-cyan-bright))))
   `(sp-show-pair-mismatch-face ((t (:background ,err-container :foreground ,on-err-container))))

   ;; Rainbow delimiters - vibrant colors
   `(rainbow-delimiters-depth-1-face ((t (:foreground ,adv-cyan))))
   `(rainbow-delimiters-depth-2-face ((t (:foreground ,adv-yellow))))
   `(rainbow-delimiters-depth-3-face ((t (:foreground ,adv-green))))
   `(rainbow-delimiters-depth-4-face ((t (:foreground ,adv-blue))))
   `(rainbow-delimiters-depth-5-face ((t (:foreground ,adv-magenta))))
   `(rainbow-delimiters-depth-6-face ((t (:foreground ,adv-cyan-bright))))
   `(rainbow-delimiters-depth-7-face ((t (:foreground ,adv-yellow-bright))))
   `(rainbow-delimiters-depth-8-face ((t (:foreground ,adv-green-bright))))
   `(rainbow-delimiters-depth-9-face ((t (:foreground ,adv-red-alt))))
   `(rainbow-delimiters-mismatched-face ((t (:foreground ,err :weight bold))))
   `(rainbow-delimiters-unmatched-face ((t (:foreground ,err :weight bold))))

   ;; Dired
   `(dired-directory ((t (:foreground ,adv-cyan :weight bold))))
   `(dired-ignored ((t (:foreground ,adv-gray))))
   `(dired-flagged ((t (:foreground ,adv-red))))
   `(dired-marked ((t (:foreground ,adv-yellow :weight bold))))
   `(dired-symlink ((t (:foreground ,adv-magenta :slant italic))))
   `(dired-header ((t (:foreground ,adv-cyan :weight bold :height 1.1))))

   ;; Terminal colors
   `(term-color-black ((t (:foreground ,term0 :background ,term0))))
   `(term-color-red ((t (:foreground ,term1 :background ,term1))))
   `(term-color-green ((t (:foreground ,term2 :background ,term2))))
   `(term-color-yellow ((t (:foreground ,term3 :background ,term3))))
   `(term-color-blue ((t (:foreground ,term4 :background ,term4))))
   `(term-color-magenta ((t (:foreground ,term5 :background ,term5))))
   `(term-color-cyan ((t (:foreground ,term6 :background ,term6))))
   `(term-color-white ((t (:foreground ,term7 :background ,term7))))

   ;; EShell
   `(eshell-prompt ((t (:foreground ,adv-cyan :weight bold))))
   `(eshell-ls-directory ((t (:foreground ,adv-cyan :weight bold))))
   `(eshell-ls-symlink ((t (:foreground ,adv-magenta :slant italic))))
   `(eshell-ls-executable ((t (:foreground ,adv-green))))
   `(eshell-ls-archive ((t (:foreground ,adv-yellow))))
   `(eshell-ls-backup ((t (:foreground ,adv-gray))))
   `(eshell-ls-clutter ((t (:foreground ,adv-red))))
   `(eshell-ls-missing ((t (:foreground ,adv-red))))
   `(eshell-ls-product ((t (:foreground ,on-surface-variant))))
   `(eshell-ls-readonly ((t (:foreground ,adv-gray))))
   `(eshell-ls-special ((t (:foreground ,adv-blue))))
   `(eshell-ls-unreadable ((t (:foreground ,adv-gray))))

   ;; Improved markdown mode
   `(markdown-header-face ((t (:foreground ,adv-cyan :weight bold))))
   `(markdown-header-face-1 ((t (:foreground ,adv-cyan :weight bold :height 1.2))))
   `(markdown-header-face-2 ((t (:foreground ,adv-blue :weight bold :height 1.1))))
   `(markdown-header-face-3 ((t (:foreground ,adv-magenta :weight bold))))
   `(markdown-header-face-4 ((t (:foreground ,adv-green :weight bold))))
   `(markdown-inline-code-face ((t (:foreground ,adv-yellow-bright :background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-code-face ((t (:background ,surface-container-low :extend t :inherit fixed-pitch))))
   `(markdown-pre-face ((t (:background ,surface-container-low :inherit fixed-pitch))))
   `(markdown-table-face ((t (:foreground ,adv-magenta :inherit fixed-pitch))))

   ;; Web mode
   `(web-mode-html-tag-face ((t (:foreground ,adv-cyan))))
   `(web-mode-html-tag-bracket-face ((t (:foreground ,adv-gray))))
   `(web-mode-html-attr-name-face ((t (:foreground ,adv-yellow))))
   `(web-mode-html-attr-value-face ((t (:foreground ,adv-green))))
   `(web-mode-css-selector-face ((t (:foreground ,adv-cyan))))
   `(web-mode-css-property-name-face ((t (:foreground ,adv-blue))))
   `(web-mode-css-string-face ((t (:foreground ,adv-green))))

   ;; Flycheck
   `(flycheck-error ((t (:underline (:style wave :color ,err)))))
   `(flycheck-warning ((t (:underline (:style wave :color ,adv-yellow)))))
   `(flycheck-info ((t (:underline (:style wave :color ,adv-blue)))))
   `(flycheck-fringe-error ((t (:foreground ,err))))
   `(flycheck-fringe-warning ((t (:foreground ,adv-yellow))))
   `(flycheck-fringe-info ((t (:foreground ,adv-blue))))

   ;; Mini-buffer customization
   `(minibuffer-prompt ((t (:foreground ,adv-cyan :weight bold))))

   ;; Improved search highlighting
   `(lsp-face-highlight-textual ((t (:background ,primary-container :foreground ,adv-cyan-bright :weight bold))))
   `(lsp-face-highlight-read ((t (:background ,secondary-container :foreground ,adv-yellow-bright :weight bold))))
   `(lsp-face-highlight-write ((t (:background ,tertiary-container :foreground ,adv-green-bright :weight bold))))

   ;; Info and help modes
   `(info-title-1 ((t (:foreground ,adv-cyan :weight bold :height 1.3))))
   `(info-title-2 ((t (:foreground ,adv-blue :weight bold :height 1.2))))
   `(info-title-3 ((t (:foreground ,adv-magenta :weight bold :height 1.1))))
   `(info-title-4 ((t (:foreground ,adv-green :weight bold))))
   `(Info-quoted ((t (:foreground ,adv-yellow))))
   `(info-menu-header ((t (:foreground ,adv-cyan :weight bold))))
   `(info-menu-star ((t (:foreground ,adv-cyan))))
   `(info-node ((t (:foreground ,adv-blue :weight bold))))

   ;; Tabs
   `(tab-bar ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(tab-bar-tab ((t (:background ,surface-container-high :foreground ,adv-cyan :weight bold :box nil))))
   `(tab-bar-tab-inactive ((t (:background ,surface :foreground ,adv-gray :box nil))))

   `(tab-line ((t (:background ,surface-container :foreground ,on-surface :box nil))))
   `(tab-line-tab ((t (:background ,surface :foreground ,adv-gray :box nil))))
   `(tab-line-tab-current ((t (:background ,surface-container-high :foreground ,adv-cyan :weight bold :box nil))))
   `(tab-line-tab-inactive ((t (:background ,surface :foreground ,adv-gray :box nil))))
   `(tab-line-highlight ((t (:background ,surface-container-highest :foreground ,adv-cyan-bright))))

   `(centaur-tabs-default ((t (:background ,surface-container :foreground ,on-surface))))
   `(centaur-tabs-selected ((t (:background ,surface-container-high :foreground ,adv-cyan :weight bold))))
   `(centaur-tabs-unselected ((t (:background ,surface :foreground ,adv-gray))))
   `(centaur-tabs-selected-modified ((t (:background ,surface-container-high :foreground ,adv-yellow :weight bold))))
   `(centaur-tabs-unselected-modified ((t (:background ,surface :foreground ,adv-yellow))))
   `(centaur-tabs-active-bar-face ((t (:background ,adv-cyan))))

   ;; Fixed-pitch faces
   `(fixed-pitch ((t (:family "monospace"))))
   `(fixed-pitch-serif ((t (:family "monospace serif"))))

   ;; Variable-pitch face
   `(variable-pitch ((t (:family "sans serif"))))
   ))

;; Add org-mode hooks for hiding leading stars
(with-eval-after-load 'org
  (setq org-hide-leading-stars t)
  (setq org-startup-indented t))

;;;###autoload
(when load-file-name
  (add-to-list 'custom-theme-load-path
               (file-name-as-directory (file-name-directory load-file-name))))

(provide-theme 'adv-emacs)
;;; adv-emacs-theme.el ends here
