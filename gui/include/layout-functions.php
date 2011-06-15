<?php
/**
 * i-MSCP a internet Multi Server Control Panel
 *
 * @copyright 	2001-2006 by moleSoftware GmbH
 * @copyright 	2006-2010 by ispCP | http://isp-control.net
 * @copyright 	2010 by i-MSCP | http://i-mscp.net
 * @version 	SVN: $Id$
 * @link 		http://i-mscp.net
 * @author 		ispCP Team
 * @author 		i-MSCP Team
 *
 * @license
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is "VHCS - Virtual Hosting Control System".
 *
 * The Initial Developer of the Original Code is moleSoftware GmbH.
 * Portions created by Initial Developer are Copyright (C) 2001-2006
 * by moleSoftware GmbH. All Rights Reserved.
 * Portions created by the ispCP Team are Copyright (C) 2006-2010 by
 * isp Control Panel. All Rights Reserved.
 * Portions created by the i-MSCP Team are Copyright (C) 2010 by
 * i-MSCP a internet Multi Server Control Panel. All Rights Reserved.
 */

if (isset($_SESSION['user_id']) && !isset($_SESSION['logged_from']) && !isset($_SESSION['logged_from_id'])) {
	list($user_def_lang, $user_def_layout) = get_user_gui_props($_SESSION['user_id']);

	$_SESSION['user_theme'] = $user_def_layout;
	$_SESSION['user_def_lang'] = $user_def_lang;
}

// THEME_COLOR management stuff.

function get_user_gui_props($user_id) {

	/**
	 * @var $cfg iMSCP_Config_Handler_File
	 */
	$cfg = iMSCP_Registry::get('config');

	$query = "
		SELECT
			`lang`, `layout`
		FROM
			`user_gui_props`
		WHERE
			`user_id` = ?
	";

	$rs = exec_query($query, $user_id);

	if ($rs->recordCount() == 0
		|| (empty($rs->fields['lang']) && empty($rs->fields['layout']))) {
		// values for user id, some default stuff
		return array($cfg->USER_INITIAL_LANG, $cfg->USER_INITIAL_THEME);
	} else if (empty($rs->fields['lang'])) {

		return array($cfg->USER_INITIAL_LANG, $rs->fields['layout']);
	} else if (empty($rs->fields['layout'])) {

		return array($rs->fields['lang'], $cfg->USER_INITIAL_THEME);
	} else {

		return array($rs->fields['lang'], $rs->fields['layout']);
	}
}

/**
 * Generate page message (info, warning, error, success)
 *
 * Note: The default message type is set to 'info'.
 * See the set_page_message() function for more information. 
 *
 * @param  iMSCP_pTemplate $tpl iMSCP_pTemplate instance
 * @return void
 */
function generatePageMessage($tpl) {

	if (!isset($_SESSION['user_page_message'])) {
		$tpl->assign('PAGE_MESSAGE', '');
	} else {
		$tpl->assign(
			array(
				'MESSAGE_CLS' => $_SESSION['user_page_message_cls'],
				'MESSAGE' => $_SESSION['user_page_message']
			)
		);

		unset($_SESSION['user_page_message'], $_SESSION['user_page_message_cls']);
	}
}

/**
 * Set page message
 *
 * This function allow to set a message (info, warning, error, success) that will be displayed on page reload.
 *
 * You can change default message type (info) like this:
 *
 * Example for error message:
 *
 * set_page_message('An error occurred here!', 'error');
 *
 * @param  string $message The message
 * @return void
 */
function set_page_message($message, $messageCls = 'info') {

	if (isset($_SESSION['user_page_message'])) {
		$_SESSION['user_page_message'] .= "\n<br />$message";
	} else {
		$_SESSION['user_page_message'] = $message;
	}

	$_SESSION['user_page_message_cls'] = $messageCls;
}

/**
 * Converts a Array of Strings to a single <br />-separated String
 * @since r2684
 *
 * @param	String[]	Array of message strings
 * @return	String		a single string with <br /> tags
 */
function format_message($message) {

	$string = '';

	foreach ($message as $msg) {
		$string .= $msg . "<br />\n";
	}

	return $string;
}

/**
 * @todo remove checks for DATABASE_REVISION >= 11, this produces unmaintainable code
 */
function get_menu_vars($menu_link) {

	/**
	 * @var $cfg iMSCP_Config_Handler_File
	 */
	$cfg = iMSCP_Registry::get('config');

	$user_id = $_SESSION['user_id'];

	$query = "
		SELECT
			`customer_id`, `fname`, `lname`, `firm`, `zip`, `city`,"
			. ($cfg->DATABASE_REVISION >= 11 ? '`state`, ' : '')
			. "`country`, `email`, `phone`, `fax`, `street1`, `street2`
		FROM
			`admin`
		WHERE
			`admin_id` = ?
	";

	$rs = exec_query($query, $user_id);

	$search = array();
	$replace = array();

	$search [] = '{uid}';
	$replace[] = $_SESSION['user_id'];
	$search [] = '{uname}';
	$replace[] = tohtml($_SESSION['user_logged']);
	$search [] = '{cid}';
	$replace[] = tohtml($rs->fields['customer_id']);
	$search [] = '{fname}';
	$replace[] = tohtml($rs->fields['fname']);
	$search [] = '{lname}';
	$replace[] = tohtml($rs->fields['lname']);
	$search [] = '{company}';
	$replace[] = tohtml($rs->fields['firm']);
	$search [] = '{zip}';
	$replace[] = tohtml($rs->fields['zip']);
	$search [] = '{city}';
	$replace[] = tohtml($rs->fields['city']);

	if ($cfg->DATABASE_REVISION >= 11) {
		$search [] = '{state}';
		$replace[] = $rs->fields['state'];
	}

	$search [] = '{country}';
	$replace[] = tohtml($rs->fields['country']);
	$search [] = '{email}';
	$replace[] = tohtml($rs->fields['email']);
	$search [] = '{phone}';
	$replace[] = tohtml($rs->fields['phone']);
	$search [] = '{fax}';
	$replace[] = tohtml($rs->fields['fax']);
	$search [] = '{street1}';
	$replace[] = tohtml($rs->fields['street1']);
	$search [] = '{street2}';
	$replace[] = tohtml($rs->fields['street2']);

	$query = "
		SELECT
			`domain_name`, `domain_admin_id`
		FROM
			`domain`
		WHERE
			`domain_admin_id` = ?
	";

	$rs = exec_query($query, $user_id);

	$search [] = '{domain_name}';
	$replace[] = $rs->fields['domain_name'];

	$menu_link = str_replace($search, $replace, $menu_link);
	return $menu_link;
}

/**
 * @todo currently not being used because there's only one layout/theme
 */
function gen_def_layout($tpl, $user_def_layout) {

	/**
	 * @var $cfg iMSCP_Config_Handler_File
	 */
	$cfg = iMSCP_Registry::get('config');

	$layouts = array('blue', 'green', 'red', 'yellow');

	foreach ($layouts as $layout) {
		$selected = ($layout === $user_def_layout) ? $cfg->HTML_SELECTED : '';

		$tpl->assign(
			array(
				'LAYOUT_VALUE' => $layout,
				'LAYOUT_SELECTED' => $selected,
				'LAYOUT_NAME' => $layout
			)
		);

		$tpl->parse('DEF_LAYOUT', '.def_layout');
	}
}
