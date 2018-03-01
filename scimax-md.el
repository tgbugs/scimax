;;; scimax-md.el --- A better exporter for markdown

;;; Commentary:
;;

(require 'ox-md)

;; * A better link exporter
;; Handle figures better, mostly with captions and labels.

(defun scimax-md-link (link contents info)
  "Export a link to markdown."
  (cond
   ;; This is an image with a caption
   ((and (string= "file" (org-element-property :type link))
	 (-contains?
	  '("png")
	  (file-name-extension
	   (org-element-property :path link)))
	 (org-export-get-caption
	  (org-element-property :parent link)))
    (format "
<figure>
  <img src=\"%s\">
  <figcaption>Figure (%s): %s</figcaption>
</figure>"
	    ;; image path
	    (org-element-property :path link)
	    ;; TODO: Figure label. This is super-hacky...
	    (let ((caption (org-export-data
			    (org-export-get-caption
			     (org-element-property :parent link))
			    info)))
	      (string-match "name=\"\\(.*?\\)\">" caption)
	      (match-string 1 caption))


	    ;; The caption
	    (org-export-data
	     (org-export-get-caption
	      (org-element-property :parent link))
	     info)))
   ;; This is at least true for radio links.
   ((string= "fuzzy" (org-element-property :type link))
    (let ((path (org-element-property :path link)))
      (format "[%s](#%s)" path path)))

   ;; file links. treat links to org files as links to md files.
   ((string= "file" (org-element-property :type link))
    (format "[%s](%s)"
	    (if (org-element-property :contents-begin link)
		(buffer-substring (org-element-property :contents-begin link)
				  (org-element-property :contents-end link))
	      (org-element-property :path link))
	    (org-element-property :path link)))

   ;; fall-through to the default exporter.
   (t
    (org-md-link link contents info))))


(defun scimax-md-target (target contents info)
  "redefine targets as a div, since they are probably readable text."
  (let ((value (org-element-property :value target)))
    (format "<a name=\"%s\"></a>%s" value value)))

;; * New export backend
;; You need this to use the functions above.

(org-export-define-derived-backend 'scimax-md 'md
  :translate-alist '((link . scimax-md-link)
		     (target . scimax-md-target)))


;; * Publishing

(defun scimax-md-publish-to-md (plist filename pub-dir)
  "Publish an org file to md.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to 'scimax-md filename
		      ".md"
		      plist pub-dir))


;; * buttons for markdown mode
(require 'button-lock)


(defun scimax-md-activate-buttons ()
  ;; Make links in markdown clickable.
  (button-lock-mode +1)

  ;; things like [Downsides to this approach](#orgbaa3187)
  ;; these are links to anchors
  (button-lock-set-button
   "\\[.*?\\](#\\(.*?\\))"
   (lambda ()
     (interactive)
     (save-excursion
       (re-search-backward "\\[")
       (when (looking-at "\\[.*?\\](#\\(.*?\\))")
	 (goto-char (match-end 1))))
     (goto-char (point-min))
     ;; look for name="label", or id="label" . Assume these are in anchors.
     (re-search-forward (format "name\\|id=\"%s\""
				(regexp-quote (match-string 1)))))
   :help-echo "This points to an anchor.")

  ;; file links
  (button-lock-set-button
   "\\[.*?\\](#\\(.*?\\))"
   (lambda ()
     (interactive)
     (save-excursion
       (re-search-backward "\\[")
       (when (looking-at "\\[.*?\\](\\(.*?\\))")
	 (cond
	  ((file-exists-p (match-string 1))
	   (find-file (match-string 1)))
	  ((s-starts-with? "http" (match-string 1))
	   (browse-url (match-string 1)))
	  (t
	   (message "I don't know what to do with %s" (match-string 1))))))
     :help-echo "This points to a file or url."))

  (add-hook 'markdown-mode-hook 'scimax-md-activate-buttons)

  (provide 'scimax-md)

;;; scimax-md.el ends here