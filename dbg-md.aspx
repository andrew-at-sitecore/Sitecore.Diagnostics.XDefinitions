<%@ Page Language="C#" AutoEventWireup="true" Debug="true" %>

<%@ Import Namespace="Newtonsoft.Json" %>

<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="Sitecore.Diagnostics" %>
<%@ Import Namespace="Sitecore.StringExtensions" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Repository" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals.Data" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Marketing.Deployment" %>

<script runat="server">
  public void Page_Load()
  {
    var dFactory = DefinitionManagerFactory.Default;

    var goalVerificationContext = new GoalVerificationContext();
    Trace(goalVerificationContext.SourceManager.GetType().ToString());
    Trace(goalVerificationContext.TargetManager.GetType().ToString());

    var scDefinitions = goalVerificationContext.SourceManager.GetAll(CultureInfo.InvariantCulture);
    Trace("SC Definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    foreach (var scDefinition in scDefinitions.OrderBy(x=>x.Data.Id.ToString()))
    {
      Trace(JsonConvert.SerializeObject(scDefinition));
    }

    var xDefinitions = goalVerificationContext.TargetManager.GetAll(CultureInfo.InvariantCulture);
    Trace("X Definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    foreach (var xDefinition in xDefinitions.OrderBy(x=>x.Data.Id.ToString()))
    {
      Trace(JsonConvert.SerializeObject(xDefinition));
    }
    Trace("[END]");
  }

  public class GoalVerificationContext
  {
    public GoalVerificationContext() {
      var deploymentManager = DeploymentManager.Default;
      var dFactory = DefinitionManagerFactory.Default;

      var deploymentManagerTargetRepositoryFld = deploymentManager.GetType().GetField("targetRepository", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
      var deploymentManagerTargetRepository = deploymentManagerTargetRepositoryFld.GetValue(deploymentManager) as string;
      Assert.IsNotNull(deploymentManagerTargetRepository, "deploymentManagerTargetRepository is NULL");

      this.SourceManager = dFactory.GetDefinitionManager<IGoalDefinition>();
      Assert.IsNotNull(SourceManager, "IGoalDefinition SourceManager is NULL");
      this.TargetManager = dFactory.GetDefinitionManager<IGoalDefinition>(deploymentManagerTargetRepository);
      Assert.IsNotNull(TargetManager, "IGoalDefinition TargetManager is NULL");
    }

    public IDefinitionManager<IGoalDefinition> SourceManager { get; private set; }
    public IDefinitionManager<IGoalDefinition> TargetManager { get; private set; }
  }

  private void Trace(string msg)
  {
    Response.Write("<pre><code>{0}</code></pre>".FormatWith(msg));
  }

</script>