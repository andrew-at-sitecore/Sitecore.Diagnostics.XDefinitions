<%@ Page Language="C#" AutoEventWireup="true" Debug="true" CodeFile="Sitecore.DiagPage.cs" Inherits="SitecoreDiagPage" %>

<%@ Import Namespace="Newtonsoft.Json" %>

<%@ Import Namespace="System.Globalization" %>
<%@ Import Namespace="Sitecore.Diagnostics" %>
<%@ Import Namespace="Sitecore.StringExtensions" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Repository" %>
<%@ Import Namespace="Sitecore.Marketing.Definitions.Goals.Data" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Marketing.Deployment" %>

<%@ Import Namespace="Sitecore.Marketing.Taxonomy" %>
<%@ Import Namespace="Sitecore.Marketing.Taxonomy.Data.Entities" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Taxonomy" %>
<%@ Import Namespace="Sitecore.Analytics.Reporting.DefinitionData.Taxonomy.Deployment" %>

<script runat="server">
  public static class Const
  {
    public static class Taxonomy
    {
      public static readonly string RdbProviderConfigPath = "/sitecore/taxonomy/repositories/rdbTaxonomyRepository";
    }
  }

  public void Page_Load()
  {
    VerifyTaxonomy();
  }

  public void VerifyTaxonomy()
  {
    var taxonomyDeployManager = DeployManagerProvider.GetManager();

    var scProvider = TaxonomyManager.Provider;
    var scTaxonomyManager = scProvider.GetManager(Sitecore.Marketing.Taxonomy.WellKnownIdentifiers.Items.Taxonomies.TaxonomyRootId, createIfMissing:true);
    var scTaxonomyDefinitions = scTaxonomyManager.GetAll();

    var rdbTaxonomyProvider = Sitecore.Configuration.Factory.CreateObject<RdbTaxonomyRepository>(Sitecore.Configuration.Factory.GetConfigNode(Const.Taxonomy.RdbProviderConfigPath));
    Assert.IsNotNull(rdbTaxonomyProvider, "rdbTaxonomyProvider is NULL [failed to fetch from configuration by xpath: '{0}']".FormatWith(Const.Taxonomy.RdbProviderConfigPath));
    Trace.Info("Started verification of taxonomy definitions deployment...");
    var clicker = new Clicker();
    //Groupping taxonomy definitions by taxonomy IDs. Each group will contain culture variations for the same taxonomy
    foreach ( var scTaxonomyDefinitionGroup in scTaxonomyDefinitions.GroupBy( taxonomy => taxonomy.TaxonomyId))
    {
      foreach (var scCultureSpecificTaxonomy in scTaxonomyDefinitionGroup) {
        var rdbCultureSpecificTaxonomy = rdbTaxonomyProvider.Get(scCultureSpecificTaxonomy.TaxonomyId, scCultureSpecificTaxonomy.Culture);
        VerifyTaxonomyAgainstScDefinition(scCultureSpecificTaxonomy, rdbCultureSpecificTaxonomy, clicker);
      }
    }
    Trace.Info("DONE [verification of taxonomy definitions deployment]");
    Trace.Clicker(clicker);
  }

  public void VerifyTaxonomyAgainstScDefinition(TaxonEntity scTaxonomyEntity, TaxonEntity rdbTaxonomyEntity, Clicker clicker)
  {
    clicker.Click();
    //API always returns a taxonomy entity ( even if the culture does not exist in the database ). Double-checking field language to confirm
    if (rdbTaxonomyEntity == null) {
      Trace.Err("The following taxonomy had not been deployed: '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
      clicker.Err();
      return;
    }

    if (rdbTaxonomyEntity.Fields == null || scTaxonomyEntity.Fields == null)
    {
      Trace.Warn("The taxonomy had been deployed but the culture cannot be confirmed '{0}:{1}' [This, most likely, is not a problem. Occurs only when a taxonomy does not have any fields associated with it]".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
      clicker.Warn();
      return;
    }

    var rdbTaxonomyField = rdbTaxonomyEntity.Fields.First();
    var scTaxonomyField = scTaxonomyEntity.Fields.First();

    if (rdbTaxonomyField == null && scTaxonomyField == null)
    {
      Trace.Warn("The taxonomy had been deployed but the culture cannot be confirmed '{0}:{1}' [This, most likely, is not a problem. Occurs only when a taxonomy does not have any fields associated with it]".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
      clicker.Warn();
      return;
    }
    else if (rdbTaxonomyField == null || scTaxonomyField == null) {
      //If only one of the fields is null - taxonomy definitions are different
      Trace.Err("Taxonomy definition mismatch for the taxonomy '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
      clicker.Err();
      return;
    }

    if (!rdbTaxonomyField.LanguageCode.Equals(scTaxonomyField.LanguageCode))
    {
      Trace.Err("Failed to confirm deployment for the following taxonomy '{0}:{1}'".FormatWith(scTaxonomyEntity.TaxonomyId, scTaxonomyEntity.Culture));
      clicker.Err();
      return;
    }
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

  public void VerifyGoalDefinitions() {
    var dFactory = DefinitionManagerFactory.Default;

    var goalVerificationContext = new GoalVerificationContext();
    Trace.Info(goalVerificationContext.SourceManager.GetType().ToString());
    Trace.Info(goalVerificationContext.TargetManager.GetType().ToString());

    var scDefinitions = goalVerificationContext.SourceManager.GetAll(CultureInfo.InvariantCulture);
    Trace.Info("SC Definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    foreach (var scDefinition in scDefinitions.OrderBy(x=>x.Data.Id.ToString()))
    {
      Trace.Info(JsonConvert.SerializeObject(scDefinition));
    }

    var xDefinitions = goalVerificationContext.TargetManager.GetAll(CultureInfo.InvariantCulture);
    Trace.Info("X Definitions ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    foreach (var xDefinition in xDefinitions.OrderBy(x=>x.Data.Id.ToString()))
    {
      Trace.Info(JsonConvert.SerializeObject(xDefinition));
    }
    Trace.Info("[END]");
  }

  public static class Trace
  {
    public static void Info(string msg)
    {
      HttpContext.Current.Response.Write(Format(msg, "green"));
    }
    public static void Warn(string msg) {
      HttpContext.Current.Response.Write(Format(msg, "orange"));
    }
    public static void Err(string msg) {
      HttpContext.Current.Response.Write(Format(msg, "red"));
    }

    public static void Clicker(Clicker clicker)
    {
      Info("STATS: TotalProcessed: '{0}'; Warnings: '{1}'; Errors: '{2}'".FormatWith(clicker.TotalProcessed, clicker.Warnings, clicker.Errors));
    }

    private static string Format(string msg, string cssMarkerColor)
    {
      return "<div style='display:table;'><span style='display:table-cell;background-color:{0}'>&nbsp;</span><code display:'table-cell;'><pre>{1}</pre></code></div>".FormatWith(cssMarkerColor, msg);
    }
  }

  public class Clicker
  {
    public int TotalProcessed { get; private set; }
    public int Warnings { get; private set; }
    public int Errors { get; private set; }

    public void Err() { this.Errors += 1; }
    public void Warn() { this.Warnings += 1; }
    public void Click() { this.TotalProcessed += 1; }

  }

</script>