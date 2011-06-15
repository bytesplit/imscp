<?xml version="1.0" encoding="{THEME_CHARSET}" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" dir="ltr" lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset={THEME_CHARSET}" />
		<meta http-equiv="X-UA-Compatible" content="IE=8" />
		<title>{TR_CLIENT_ADD_SUBDOMAIN_PAGE_TITLE}</title>
		<meta name="robots" content="nofollow, noindex" />
		<link href="{THEME_COLOR_PATH}/css/imscp.css" rel="stylesheet" type="text/css" />
		<script type="text/javascript" src="{THEME_COLOR_PATH}/js/imscp.js"></script>
		<script type="text/javascript" src="{THEME_COLOR_PATH}/js/jquery.js"></script>
		<script type="text/javascript" src="{THEME_COLOR_PATH}/js/jquery.imscpTooltips.js"></script>
		<!--[if IE 6]>
		<script type="text/javascript" src="{THEME_COLOR_PATH}/js/DD_belatedPNG_0.0.8a-min.js"></script>
		<script type="text/javascript">
			DD_belatedPNG.fix('*');
		</script>
		<![endif]-->
		<script language="JavaScript" type="text/JavaScript">
			/*<![CDATA[*/
				$(document).ready(function(){
					// Tooltips - begin
					$('#dmn_help').iMSCPtooltips({msg:"{TR_DMN_HELP}"});
					// Tooltips - end
					
					// Request for encode_idna request
					$('input[name=subdomain_name]').blur(function(){
						subdmnName = $('#subdomain_name').val();
						// Configure the request for encode_idna request
						$.ajaxSetup({
						url: $(location).attr('pathname'),
							type:'POST',
							data: 'subdomain=' + subdmnName + '&uaction=toASCII',
							datatype: 'text',
							beforeSend: function(xhr){xhr.setRequestHeader('Accept','text/plain');},
							success: function(r){$('#subdomain_mnt_pt').val(r);},
							error: iMSCPajxError
						});
						$.ajax();
					});
				});
				
				function setRatioAlias(){
					document.forms[0].elements['dmn_type'][1].checked = true;
				}

				function setForwardReadonly(obj){
					if(obj.value == 1) {
						document.forms[0].elements['forward'].readOnly = false;
						document.forms[0].elements['forward_prefix'].disabled = false;
					} else {
						document.forms[0].elements['forward'].readOnly = true;
						document.forms[0].elements['forward'].value = '';
						document.forms[0].elements['forward_prefix'].disabled = true;
					}
				}

			/*]]>*/
		</script>
	</head>
	<body>
		<div class="header">
			{MAIN_MENU}

			<div class="logo">
				<img src="{THEME_COLOR_PATH}/images/imscp_logo.png" alt="i-MSCP logo" />
			</div>
		</div>

		<div class="location">
			<div class="location-area icons-left">
				<h1 class="domains">{TR_MENU_MANAGE_DOMAINS}</h1>
			</div>
			<ul class="location-menu">
				<!-- <li><a class="help" href="#">Help</a></li> -->
				<!-- BDP: logged_from -->
				<li><a class="backadmin" href="change_user_interface.php?action=go_back">{YOU_ARE_LOGGED_AS}</a></li>
				<!-- EDP: logged_from -->
				<li><a class="logout" href="../index.php?logout">{TR_MENU_LOGOUT}</a></li>
			</ul>
			<ul class="path">
				<li><a href="domains_manage.php">{TR_MENU_MANAGE_DOMAINS}</a></li>
				<li><a href="subdomain_add.php">{TR_MENU_ADD_SUBDOMAIN}</a></li>
			</ul>
		</div>

		<div class="left_menu">
			{MENU}
		</div>

		<div class="body">
			<h2 class="domains"><span>{TR_ADD_SUBDOMAIN}</span></h2>
			<!-- BDP: page_message -->
				<div class="{MESSAGE_CLS}">{MESSAGE}</div>
			<!-- EDP: page_message -->


			<form name="client_add_subdomain_frm" method="post" action="subdomain_add.php">
				<table>
					<tr>
						<td style="width: 300px;">
							<label for="subdomain_name">{TR_SUBDOMAIN_NAME}</label><span class="icon i_help" id="dmn_help">Help</span>
						</td>
						<td style="width: 300px;">
							<input type="text" name="subdomain_name" id="subdomain_name" value="{SUBDOMAIN_NAME}" />
						</td>
						<td>
							<input type="radio" name="dmn_type" value="dmn" {SUB_DMN_CHECKED}" />{DOMAIN_NAME}
							<!-- BDP: to_alias_domain -->
								<br />
								<input type="radio" name="dmn_type" value="als" {SUB_ALS_CHECKED}" />
								<select name="als_id">
									<!-- BDP: als_list -->
										<option value="{ALS_ID}" {ALS_SELECTED}>.{ALS_NAME}</option>
									<!-- EDP: als_list -->
								</select>
							<!-- EDP: to_alias_domain -->
						</td>
					</tr>
					<tr>
						<td>
							<label for="subdomain_mnt_pt">{TR_DIR_TREE_SUBDOMAIN_MOUNT_POINT}</label>
						</td>
						<td colspan=2">
							<input type="text" name="subdomain_mnt_pt" id="subdomain_mnt_pt" value="{SUBDOMAIN_MOUNT_POINT}" />
						</td>
					</tr>
					<tr>
						<td>
							<label for="status">{TR_ENABLE_FWD}</label>
						</td>
						<td colspan=2">
							<input type="radio" name="status" {CHECK_EN} value="1" onchange='setForwardReadonly(this);' />{TR_ENABLE}<br />
							<input type="radio" name="status" {CHECK_DIS} value="0" onchange='setForwardReadonly(this);' />{TR_DISABLE}
						</td>
					</tr>
					<tr>
						<td>
							<label for="forward">{TR_FORWARD}</label>
						</td>
						<td colspan=2">
							<select name="forward_prefix" style="vertical-align:middle"{DISABLE_FORWARD}>
								<option value="{TR_PREFIX_HTTP}"{HTTP_YES}>{TR_PREFIX_HTTP}</option>
								<option value="{TR_PREFIX_HTTPS}"{HTTPS_YES}>{TR_PREFIX_HTTPS}</option>
								<option value="{TR_PREFIX_FTP}"{FTP_YES}>{TR_PREFIX_FTP}</option>
							</select>
							<input name="forward" type="text" class="textinput" id="forward" style="width:170px" value="{FORWARD}"{READONLY_FORWARD} />
						</td>
					</tr>
				</table>

				<div class="buttons">
					<input name="Submit" type="submit" class="button" value="{TR_ADD}" />
				</div>

				<input type="hidden" name="uaction" value="add_subd" />
			</form>
		</div>

		<div class="footer">
			i-MSCP {VERSION}<br />build: {BUILDDATE}<br />Codename: {CODENAME}
		</div>

	</body>
</html>
