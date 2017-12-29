class NoteEntity < API::Entities::Note
  include RequestAwareEntity

  expose :type

  expose :author, using: NoteUserEntity

  expose :human_access do |note|
    note.project.team.human_max_access(note.author_id)
  end

  unexpose :note, as: :body
  expose :note

  expose :redacted_note_html, as: :note_html

  expose :last_edited_at, if: ->(note, _) { note.edited? }
  expose :last_edited_by, using: NoteUserEntity, if: ->(note, _) { note.edited? }

  expose :current_user do
    expose :can_edit do |note|
      Ability.can_edit_note?(request.current_user, note)
    end
  end

  expose :system_note_icon_name, if: ->(note, _) { note.system? } do |note|
    SystemNoteHelper.system_note_icon_name(note)
  end

  expose :discussion_id do |note|
    note.discussion_id(request.noteable)
  end

  expose :emoji_awardable?, as: :emoji_awardable
  expose :award_emoji, if: ->(note, _) { note.emoji_awardable? }, using: AwardEmojiEntity
  expose :toggle_award_path, if: ->(note, _) { note.emoji_awardable? } do |note|
    if note.for_personal_snippet?
      toggle_award_emoji_snippet_note_path(note.noteable, note)
    else
      toggle_award_emoji_project_note_path(note.project, note.id)
    end
  end

  expose :report_abuse_path do |note|
    new_abuse_report_path(user_id: note.author.id, ref_url: Gitlab::UrlBuilder.build(note))
  end

  expose :path do |note|
    if note.for_personal_snippet?
      snippet_note_path(note.noteable, note)
    else
      project_note_path(note.project, note)
    end
  end

  expose :attachment, using: NoteAttachmentEntity, if: ->(note, _) { note.attachment? }
  expose :delete_attachment_path, if: ->(note, _) { note.attachment? } do |note|
    delete_attachment_project_note_path(note.project, note)
  end
end
