"""
Custom stdout callback to remove the long '*************' banners.

Keeps the default callback behavior for results, but prints a plain:
  TASK [name]
line instead of the banner.
"""

from __future__ import annotations

from ansible.plugins.callback.default import CallbackModule as DefaultCallback


class CallbackModule(DefaultCallback):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "stdout"
    CALLBACK_NAME = "clean"

    def v2_playbook_on_task_start(self, task, is_conditional):  # noqa: N802 (Ansible naming)
        # Default callback prints a banner with lots of '*'. Replace with a simple line.
        name = task.get_name().strip()
        self._display.display(f"TASK [{name}]")

