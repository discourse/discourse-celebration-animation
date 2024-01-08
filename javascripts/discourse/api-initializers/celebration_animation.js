import { apiInitializer } from "discourse/lib/api";
import CelebrationAnimation from "../components/celebration-animation";

const OBJECT_NAME = "animationLikeSolutionToggled";

export default apiInitializer("1.13.0", (api) => {
  api.renderInOutlet("above-site-header", CelebrationAnimation);

  const animationEventHandler = api.container.lookup("service:animation-event");

  function handleToggledAction() {
    if (
      settings.test_mode ||
      animationEventHandler.storageExpired(OBJECT_NAME)
    ) {
      animationEventHandler.handleActionToggled();
      if (!settings.test_mode) {
        animationEventHandler.setLocalStorage(OBJECT_NAME);
      }
    }
  }

  if (
    settings.display_mode === "first like or solution" ||
    settings.display_mode === "first visit and first like or solution"
  ) {
    api.onAppEvent("discourse-reactions:reaction-toggled", (post) => {
      // Trigger on like, not removing a like
      if (post.reaction?.can_undo) {
        handleToggledAction();
      }
    });

    api.onAppEvent("discourse-solved:solution-toggled", (post) => {
      // Trigger on solution, not removing a solution
      if (!post.topic_accepted_answer) {
        handleToggledAction();
      }
    });
  }
});
