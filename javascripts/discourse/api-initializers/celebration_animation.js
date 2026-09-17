import { apiInitializer } from "discourse/lib/api";
import CelebrationAnimation from "../components/celebration-animation";

const OBJECT_NAME = "animationLikeSolutionToggled";

export default apiInitializer((api) => {
  api.renderInOutlet("above-site-header", CelebrationAnimation);

  const animationEventHandler = api.container.lookup("service:animation-event");

  function handleToggledAction() {
    if (
      animationEventHandler.isTestUser ||
      animationEventHandler.storageExpired(OBJECT_NAME)
    ) {
      animationEventHandler.handleActionToggled();
      if (!animationEventHandler.isTestUser) {
        animationEventHandler.setLocalStorage(OBJECT_NAME);
      }
    }
  }

  if (
    settings.display_mode === "first like or solution" ||
    settings.display_mode === "first visit and first like or solution" ||
    settings.display_mode === "every other day and first solution"
  ) {
    if (settings.display_mode !== "every other day and first solution") {
      api.onAppEvent("discourse-reactions:reaction-toggled", (post) => {
        // Trigger on like, not removing a like
        if (post.reaction?.can_undo) {
          handleToggledAction();
        }
      });
    }

    api.onAppEvent("discourse-solved:solution-toggled", (post) => {
      // Trigger on solution, not removing a solution
      if (!post.topic_accepted_answer) {
        handleToggledAction();
      }
    });
  }
});
