class TasksController < InheritedResources::Base

  private

    def task_params
      params.require(:task).permit(:pid, :name, :status, :progress)
    end
end

