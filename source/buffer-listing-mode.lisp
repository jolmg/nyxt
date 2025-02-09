;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/buffer-listing-mode
  (:use :common-lisp :trivia :nyxt)
  (:documentation "Mode for buffer-listings"))
(in-package :nyxt/buffer-listing-mode)

(define-mode buffer-listing-mode ()
  "Mode for buffer-listing."
  ((rememberable-p nil)))

(define-command nyxt::list-buffers (&key (cluster nil))
  "Show the *Buffers* buffer."
  (labels ((cluster-buffers ()
             "Return buffers as hash table, where each value is a cluster (list of documents)."
             (let ((collection (make-instance 'analysis::document-collection)))
               (loop for buffer in (buffer-list)
                     unless (internal-buffer-p buffer)
                     do (with-current-buffer buffer
                          (analysis::add-document
                           collection
                           (make-instance 'analysis::document-cluster
                                          :source buffer
                                          :string-contents (document-get-paragraph-contents)))))
               (analysis::tf-vectorize-documents collection)
               (analysis::generate-document-distance-vectors collection)
               (analysis::dbscan collection :minimum-points 3 :epsilon 0.065)
               (analysis::clusters collection)))
           (buffer-markup (buffer)
             "Create the presentation for a buffer."
             (markup:markup
              (:p (:a :class "button"
                      :href (lisp-url `(nyxt::delete-buffer :id ,(id buffer))) "✕")
                  (:a :class "button"
                      :href (lisp-url `(nyxt::switch-buffer :id ,(id buffer))) "→")
                  (:span (title buffer) " - "(quri:render-uri (url buffer))))))
           (cluster-markup (cluster-id cluster)
             "Create the presentation for a cluster."
             (markup:markup
              (:div (:h2 (format nil "Cluster ~a" cluster-id))
                    (loop for document in cluster
                          collect (buffer-markup (analysis::source document))))))
           (internal-buffers-markup ()
             "Create the presentation for the internal buffers."
             (markup:markup
              (:div (:h2 "Internal Buffers")
                    (loop for buffer in (buffer-list)
                          when (internal-buffer-p buffer)
                          collect (buffer-markup buffer))))))
    (with-current-html-buffer (buffer "*Buffers*" 'nyxt/buffer-listing-mode:buffer-listing-mode)
      (markup:markup
       (:style (style buffer))
       (:h1 "Buffers")
       (:a :class "button" :href (lisp-url '(nyxt::list-buffers)) "Update")
       (:br "")
       (:div
        (if cluster
            (append (list (internal-buffers-markup)) 
                    (loop for cluster-key being the hash-key
                          using (hash-value cluster) of (cluster-buffers)
                          collect (cluster-markup cluster-key cluster)))
            (loop for buffer in (buffer-list)
                  collect (buffer-markup buffer))))))))
